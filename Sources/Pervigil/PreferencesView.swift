import SwiftUI
import AppKit
import PervigilCore

/// The Preferences window: a sidebar of pages, each opening with a live
/// picture of what its settings do (see design/concepts/settings/opus).
///
/// A sidebar replaced the old tab strip, which needed four shrinking
/// fallbacks to fit seven tabs in 15 languages. A sidebar fits any label,
/// carries live badges, and leaves room for search.
struct PreferencesView: View {
    let updater: any Updating
    @Bindable var model: AppModel
    @State private var page: SettingsPage = .general
    @State private var query = ""
    /// Which Lid & Battery tile shows its options, kept across page switches.
    @State private var powerTile: PowerTile = .lid
    /// The row a search result or a cross-page link points at: scrolled to
    /// and briefly highlighted.
    @State private var highlight: String?
    @State private var highlightTask: Task<Void, Never>?
    /// Closed Preferences windows stay alive on current macOS; unmount the
    /// pages while off screen so they stop observing AppModel every tick.
    /// Starts false so a retained ordered-out scene does not mount Forms
    /// until a real visibility probe (same pattern as WelcomeView).
    @State private var windowVisible = false
    /// Bumped on each hide so the next open does not reuse SwiftUI identity
    /// for the previous page tree (drops any leftover view storage).
    @State private var mountGeneration = 0

    var body: some View {
        Group {
            if windowVisible {
                NavigationSplitView {
                    SettingsSidebar(model: model, page: $page, searching: !query.isEmpty) { target in
                        query = ""
                        navigate(to: target, anchor: nil)
                    }
                    .navigationSplitViewColumnWidth(234)
                    .toolbar(removing: .sidebarToggle)
                } detail: {
                    detail
                }
                .searchable(text: $query, placement: .sidebar, prompt: Text(verbatim: L("Search")))
                .navigationTitle(query.isEmpty ? page.title : L("Search"))
                .id(mountGeneration)
                // The helper can be approved (or revoked) over in System Settings at
                // any time; re-read on every open so each page tells the truth.
                .onAppear { model.helper.refresh() }
            } else {
                Color.clear
            }
        }
        .frame(width: 820, height: 640)
        .tint(.pervigilAccent)
        .centersAndFrontsWindow()
        .background(WindowVisibilityReader(isVisible: $windowVisible))
        .onAppear { SettingsPage.isLaptop = model.machineHasBattery }
        .onChange(of: windowVisible) { _, visible in
            if visible {
                model.helper.refresh()
            } else {
                mountGeneration &+= 1
                query = ""
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if !query.isEmpty {
            SettingsSearchResults(query: query) { target, anchor in
                query = ""
                navigate(to: target, anchor: anchor)
            }
        } else {
            ScrollViewReader { proxy in
                content
                    .environment(\.settingsHighlight, highlight)
                    .id(page)
                    .onChange(of: highlight) { _, anchor in
                        guard let anchor else { return }
                        // Let the page lay out first, then bring the row in.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(anchor, anchor: .center) }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let go: (SettingsPage, String?) -> Void = { target, anchor in navigate(to: target, anchor: anchor) }
        switch page {
        case .general: SettingsGeneralPage(updater: updater, model: model, navigate: go)
        case .menuBar: SettingsMenuBarPage(model: model)
        case .keepAwake: SettingsKeepAwakePage(model: model)
        case .power: SettingsPowerPage(model: model, tile: $powerTile, navigate: go)
        case .triggers: SettingsTriggersPage(model: model, navigate: go)
        case .reminders: SettingsRemindersPage(model: model, navigate: go)
        case .automation: SettingsAutomationPage(model: model, navigate: go)
        case .devices: SettingsDevicesPage(model: model)
        case .activity: SettingsActivityPage(model: model)
        case .helper: SettingsHelperPage(model: model, navigate: go)
        }
    }

    /// Open a page, and when an anchor is given, scroll to that row and flash
    /// it. Lid & Battery anchors also pick the tile that shows them.
    private func navigate(to target: SettingsPage, anchor: String?) {
        if target == .power, let anchor, let tile = PowerTile(anchor: anchor) {
            powerTile = tile
        }
        page = target
        highlightTask?.cancel()
        highlight = nil
        guard let anchor else { return }
        highlightTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            highlight = anchor
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            highlight = nil
        }
    }
}

// MARK: - Pages

/// The Settings pages, in sidebar order.
enum SettingsPage: String, CaseIterable, Identifiable, Hashable {
    case general, menuBar, keepAwake, power
    case triggers, reminders, automation
    case devices, activity, helper

    var id: String { rawValue }

    /// Lid & Battery reads as Sleep & Network on a Mac with no lid. Set when
    /// the window appears; the hardware never changes under a running app.
    @MainActor static var isLaptop = true

    /// Sidebar groups, separated by a divider.
    static let groups: [[SettingsPage]] = [
        [.general, .menuBar, .keepAwake, .power],
        [.triggers, .reminders, .automation],
        [.devices, .activity, .helper],
    ]

    @MainActor var title: String {
        switch self {
        case .general: L("General")
        case .menuBar: L("Menu Bar")
        case .keepAwake: L("Keep Awake")
        case .power: Self.isLaptop ? L("Lid & Battery") : L("Sleep & Network")
        case .triggers: L("Triggers")
        case .reminders: L("Reminders")
        case .automation: L("Automation")
        case .devices: L("Devices")
        case .activity: L("Activity")
        case .helper: L("Administrator Helper")
        }
    }

    /// `nil` draws the brand mark instead of a symbol.
    @MainActor var symbol: String? {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .keepAwake: nil
        case .power: Self.isLaptop ? "laptopcomputer" : "moon"
        case .triggers: "checklist"
        case .reminders: "bell"
        case .automation: "bolt"
        case .devices: "externaldrive"
        case .activity: "chart.bar"
        case .helper: "lock.shield"
        }
    }

    /// The sidebar tile's gradient, top to bottom (System Settings grammar).
    var colors: (Color, Color) {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
        switch self {
        case .general: return (rgb(158, 163, 171), rgb(125, 130, 138))
        case .menuBar: return (rgb(79, 160, 247), rgb(26, 115, 232))
        case .keepAwake: return (.panelTileTop, .panelTileBottom)
        case .power: return (rgb(67, 200, 103), rgb(36, 161, 72))
        case .triggers, .activity: return (rgb(60, 198, 214), rgb(15, 155, 176))
        case .reminders: return (rgb(255, 107, 94), rgb(229, 55, 43))
        case .automation: return (rgb(124, 124, 245), rgb(85, 82, 219))
        case .devices: return (rgb(127, 162, 199), rgb(79, 118, 163))
        case .helper: return (rgb(140, 155, 176), rgb(95, 110, 133))
        }
    }
}

/// A page's solid tile: white glyph on its gradient, as in System Settings.
struct SidebarTile: View {
    let page: SettingsPage
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(LinearGradient(colors: [page.colors.0, page.colors.1], startPoint: .top, endPoint: .bottom))
            if let symbol = page.symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.55, weight: .medium))
                    .foregroundStyle(.white)
            } else {
                ZStack {
                    MarkPart(part: .body).fill(style: FillStyle(eoFill: true))
                    MarkPart(part: .bar(level: 1))
                }
                .foregroundStyle(.white)
                .frame(width: size * 0.5 * BrandMark.aspectRatio, height: size * 0.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Sidebar

private struct SettingsSidebar: View {
    @Bindable var model: AppModel
    @Binding var page: SettingsPage
    let searching: Bool
    let open: (SettingsPage) -> Void

    var body: some View {
        List(selection: Binding(get: { searching ? nil : page }, set: { if let new = $0 { open(new) } })) {
            Section {
                StatusCard(model: model) { open(.activity) }
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 6, trailing: 0))
            }
            ForEach(Array(SettingsPage.groups.enumerated()), id: \.offset) { _, group in
                Section {
                    ForEach(group) { item in
                        HStack(spacing: 8) {
                            SidebarTile(page: item)
                            Text(verbatim: item.title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Spacer(minLength: 4)
                            badge(item)
                        }
                        .tag(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func badge(_ item: SettingsPage) -> some View {
        switch item {
        case .triggers:
            if model.triggersEnabled {
                let met = (model.ruleStates() ?? []).filter { $0.satisfied || $0.inGrace }.count
                Text(verbatim: L("%d met", met)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            } else {
                Text(verbatim: L("Off")).font(.caption).foregroundStyle(.secondary)
            }
        case .automation:
            let leases = model.session.liveLeases.count
            if leases > 0 {
                Text(verbatim: leases == 1 ? L("1 lease") : L("%d leases", leases))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        case .activity:
            if model.session.isActive { dot(.green) }
        case .helper:
            if model.helperInstalled && !model.helper.daemonOutdated {
                dot(.green)
            } else if model.helper.awaitingApproval || model.helper.daemonOutdated {
                dot(.orange)
            }
        default:
            EmptyView()
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 7, height: 7).accessibilityHidden(true)
    }
}

/// The panel's status card in miniature, so the window always says whether
/// the Mac is awake and why. Opens Activity.
private struct StatusCard: View {
    @Bindable var model: AppModel
    let open: () -> Void

    var body: some View {
        let status = model.panelStatus()
        Button(action: open) {
            HStack(spacing: 9) {
                MarkTile(state: status.state, held: status.heldByAutomation, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: status.title).font(.system(size: 12.5, weight: .semibold))
                    Text(verbatim: reason(status))
                        .font(.system(size: 11))
                        .foregroundStyle(status.tone == .warning ? AnyShapeStyle(Color.panelAmberText) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("See what is keeping the Mac awake"))
    }

    private func reason(_ status: PanelStatus) -> String {
        // The panel's idle line is an instruction for the panel ("Press the
        // mark or pick a duration"); here, say what the Mac will do instead.
        if status.state == .canSleep && !(model.triggersEnabled && !model.triggersPaused) {
            return L("Sleeps as usual")
        }
        if let subtitle = status.subtitle { return subtitle }
        let labels = status.reasons.map(\.label)
        return labels.isEmpty ? (status.detail ?? "") : labels.joined(separator: " · ")
    }
}

// MARK: - Search

private struct SettingsSearchResults: View {
    let query: String
    let open: (SettingsPage, String) -> Void

    var body: some View {
        let results = SettingsSearch.results(for: query, in: SettingsSearchIndex.entries())
        Form {
            Section {
                if results.isEmpty {
                    Text(verbatim: L("Try \u{201C}lid\u{201D}, \u{201C}battery\u{201D}, \u{201C}sleep\u{201D}, or \u{201C}MCP\u{201D}."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { entry in
                        let target = SettingsPage(rawValue: entry.page) ?? .general
                        Button { open(target, entry.anchor) } label: {
                            HStack(spacing: 10) {
                                SidebarTile(page: target)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(verbatim: entry.title)
                                    Text(verbatim: [target.title, entry.group.flatMap { $0.caseInsensitiveCompare(target.title) == .orderedSame ? nil : $0 }]
                                        .compactMap { $0 }.joined(separator: " \u{25B8} "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: L("Results for \u{201C}%@\u{201D}", query))
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(.primary)
                    Text(verbatim: results.isEmpty ? L("No settings match.") : (results.count == 1 ? L("1 setting") : L("%d settings", results.count)))
                        .font(.callout).foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)
                .textCase(nil)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Jump highlight

private struct SettingsHighlightKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The anchor a search result or link just jumped to.
    var settingsHighlight: String? {
        get { self[SettingsHighlightKey.self] }
        set { self[SettingsHighlightKey.self] = newValue }
    }
}

/// Makes a row a jump target: scrollable to by id, and briefly tinted when
/// a search result or a link lands on it.
private struct SettingsAnchor: ViewModifier {
    let id: String
    @Environment(\.settingsHighlight) private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .id(id)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.panelAccentSolid.opacity(highlight == id ? 0.16 : 0))
                    .padding(-4)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: highlight)
            }
    }
}

extension View {
    func settingsAnchor(_ id: String) -> some View {
        modifier(SettingsAnchor(id: id))
    }
}

// MARK: - Search index

/// Every searchable setting, with the anchor its page scrolls to. Titles go
/// through `L()`, so search matches in the language the app runs in.
enum SettingsSearchIndex {
    @MainActor
    static func entries() -> [SettingsSearchEntry] {
        func e(_ page: SettingsPage, _ anchor: String, _ title: String, _ group: String? = nil, _ keywords: [String] = []) -> SettingsSearchEntry {
            SettingsSearchEntry(page: page.rawValue, anchor: anchor, title: title, group: group, keywords: keywords)
        }
        let lid = SettingsPage.isLaptop ? L("Closed-display mode") : L("Disable sleep")
        return [
            e(.general, "updates", L("Check for Updates…"), nil, ["version", "sparkle", "update"]),
            e(.general, "login", L("Launch at login"), L("Startup")),
            e(.general, "startOnLaunch", L("Start keep-awake on launch"), L("Startup")),
            e(.general, "shortcut", L("Toggle shortcut"), L("Global shortcut"), ["hotkey", "keyboard"]),
            e(.general, "language", L("App language"), L("Language")),
            e(.general, "backup", L("Export Settings\u{2026}"), L("Settings file"), ["import", "backup", "json"]),
            e(.general, "welcome", L("Show Welcome Screen\u{2026}"), L("Welcome")),
            e(.menuBar, "countdown", L("Show countdown in menu bar"), L("Status item")),
            e(.menuBar, "panelSize", L("Panel size"), L("Panel"), ["compact", "full"]),
            e(.menuBar, "glass", L("See-through"), L("Panel"), ["glass", "transparency", "frosty", "liquid"]),
            e(.menuBar, "quickStop", L("Quick stop shortcuts"), nil, ["stop in", "duration"]),
            e(.menuBar, "customize", L("Customize menu sections"), L("Custom layout")),
            e(.keepAwake, "system", L("Prevent system sleep"), L("Keep awake")),
            e(.keepAwake, "display", L("Prevent display sleep"), L("Keep awake"), ["screen"]),
            e(.keepAwake, "dim", L("Dim the display when idle"), L("Display"), ["brightness"]),
            e(.keepAwake, "presence", L("Keep me active"), L("Presence"), ["idle", "away", "teams", "slack", "f15", "mouse"]),
            e(.power, "lidMode", SettingsPage.isLaptop ? L("Keep awake with the lid closed") : L("Disable system sleep"), lid, ["pmset", "disablesleep", "clamshell"]),
            e(.power, "lidPolicy", L("If the lid shuts"), lid, ["brightness", "screen"]),
            e(.power, "lowPower", L("Low Power Mode while the lid is closed"), lid),
            e(.power, "mute", L("Mute built-in speakers while the lid is closed"), lid, ["sound", "audio"]),
            e(.power, "battery", L("Pause on low battery"), L("Battery guard"), ["threshold", "charge"]),
            e(.power, "heat", L("Pause when running hot"), L("Heat guard"), ["thermal", "temperature", "fan"]),
            e(.power, "fanMinimum", L("Minimum fan speed with the lid closed"), L("Heat guard"), ["fan"]),
            e(.power, "hotspot", L("Hotspot"), nil, ["iphone", "wifi", "network", "personal hotspot"]),
            e(.triggers, "rules", L("Triggers"), nil, ["rules", "conditions", "any", "all", "agent", "app", "microphone"]),
            e(.triggers, "presets", L("Presets"), L("Triggers"), ["meetings", "gaming", "ai agent"]),
            e(.reminders, "reminder", L("Remind me it's still on"), L("While a session runs"), ["notification", "repeat", "sound"]),
            e(.reminders, "notifyEnd", L("Notify when a session ends"), L("When a session ends on its own")),
            e(.reminders, "endingSoon", L("Warn before a timed session ends"), L("When a session ends on its own")),
            e(.automation, "leases", L("Allow automation leases"), L("Automation access"), ["lease", "cli", "agent"]),
            e(.automation, "connect", L("Copy MCP Setup"), L("Automation access"), ["mcp", "instructions", "skill", "claude", "codex"]),
            e(.automation, "syncToggle", L("Wake for scheduled AI runs"), L("Scheduled AI runs"), ["routines", "claude desktop", "codex", "tokenstat"]),
            e(.automation, "wakeToggle", L("Wake schedule"), L("Scheduled wake"), ["pmset", "alarm"]),
            e(.automation, "endChoices", L("Sleep the Mac"), L("After the session ends"), ["lock", "screen saver", "display"]),
            e(.automation, "hooks", L("Event hooks"), nil, ["webhook", "shortcut", "shell", "ntfy"]),
            e(.devices, "disk", L("Keep a disk spinning"), L("Disk"), ["nas", "external", "drive"]),
            e(.devices, "virtualDisplay", L("Create a virtual display"), L("Headless display"), ["hidpi", "vnc", "screen sharing"]),
            e(.activity, "now", L("Keeping the Mac awake now"), nil, ["assertions", "pmset", "why"]),
            e(.activity, "week", L("Awake this week"), nil, ["stats", "hours", "battery"]),
            e(.activity, "log", L("Pervigil decisions"), nil, ["log", "history"]),
            e(.helper, "status", L("Administrator helper"), nil, ["root", "daemon", "password", "privileged"]),
        ]
    }
}
