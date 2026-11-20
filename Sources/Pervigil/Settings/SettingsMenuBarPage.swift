import SwiftUI
import AppKit
import PervigilCore

/// Menu Bar: what the status item shows and how the panel looks, with a
/// preview that follows every change.
struct SettingsMenuBarPage: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    /// The presets the quick stop shortcuts choose from.
    private static let quickStopOptions: [TimeInterval] = [
        5 * 60, 10 * 60, 15 * 60, 20 * 60, 30 * 60, 45 * 60,
        60 * 60, 90 * 60, 2 * 60 * 60, 3 * 60 * 60, 4 * 60 * 60,
    ]

    var body: some View {
        Form {
            Section {
                MenuBarPreview(
                    showCountdown: model.showCountdownInMenuBar,
                    expanded: model.menuPanelExpanded,
                    clarity: model.glassClarity)
                    .listRowInsets(EdgeInsets())
                    .settingsAnchor("preview")
            } header: {
                PageHeader(page: .menuBar, summary: L("What the status item shows and how the panel looks. The preview follows your changes."))
            }

            Section {
                ToggleRow(
                    title: L("Show countdown in menu bar"),
                    subtitle: L("Shows the remaining time next to the menu-bar icon during a timed session."),
                    symbol: "timer",
                    isOn: Binding(get: { model.showCountdownInMenuBar }, set: { model.showCountdownInMenuBar = $0 }))
                    .settingsAnchor("countdown")
            } header: {
                GroupHeader(L("Status item"))
            }

            Section {
                LabeledContent {
                    Picker("", selection: Binding(get: { model.menuPanelExpanded }, set: { model.menuPanelExpanded = $0 })) {
                        Text(verbatim: L("Full panel")).tag(true)
                        Text(verbatim: L("Compact strip")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel(L("Panel size"))
                } label: {
                    RowLabel(
                        title: L("Panel size"),
                        subtitle: model.menuPanelExpanded
                            ? L("Status, triggers or durations, guards, and the footer.")
                            : L("Only the status card. Its chevron opens the full panel."),
                        symbol: "menubar.rectangle")
                }
                .settingsAnchor("panelSize")

                LabeledContent {
                    HStack(spacing: 8) {
                        Image(systemName: "snowflake").foregroundStyle(.secondary).accessibilityHidden(true)
                        Slider(
                            value: Binding(get: { Double(model.glassClarity) }, set: { model.glassClarity = Int($0) }),
                            in: 0...100, step: 5)
                            .frame(width: 150)
                            .accessibilityLabel(L("Window transparency"))
                        Image(systemName: "circle.dotted").foregroundStyle(.secondary).accessibilityHidden(true)
                        Text(verbatim: "\(model.glassClarity)%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 38, alignment: .trailing)
                    }
                } label: {
                    RowLabel(title: L("See-through"), subtitle: L("The menu-bar dropdown's glass, from frosty to clear Liquid Glass."), symbol: "sun.max")
                }
                .settingsAnchor("glass")
            } header: {
                GroupHeader(L("Panel"), info: L("How see-through the menu-bar dropdown is. Frosty (0%) backs its glass with blur and a wash of the window color, so text stays crisp on any wallpaper. Sliding toward 100% thins that backing away until the panel is the system's bare Liquid Glass, letting the desktop shine through, with some contrast cost on busy or very dark wallpapers. Changes apply instantly, only to the dropdown (windows like this one keep their standard look), and the system's Reduce Transparency accessibility setting always wins."))
            }

            Section {
                QuickStopEditor(durations: Binding(get: { model.quickStopDurations }, set: { model.quickStopDurations = $0 }),
                                options: Self.quickStopOptions)
                    .settingsAnchor("quickStop")
            } header: {
                GroupHeader(L("Quick stop shortcuts"), info: L("While a session runs, the menu shows these as one-click \u{201C}Stop in\u{201D} buttons. Clicking one converts the running session to end that much later, so the Mac goes back to sleeping on its own without you remembering to switch it off. It continues the session rather than restarting it, and clicking another button simply replaces the countdown. Up to four, and the list stays sorted."))
            } footer: {
                sectionFooter("One-click \u{201C}Stop in\u{201D} buttons shown in the menu while a session runs.")
            }

            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        if model.menuCustomizationEnabled {
                            Button(L("Customize Menu…")) {
                                NSApp.activate(ignoringOtherApps: true)
                                openWindow(id: PervigilApp.menuCustomizationWindowID)
                            }
                        }
                        Toggle("", isOn: Binding(get: { model.menuCustomizationEnabled }, set: { model.menuCustomizationEnabled = $0 }))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(L("Customize menu sections"))
                    }
                } label: {
                    RowLabel(
                        title: L("Customize menu sections"),
                        subtitle: L("Replaces the standard dropdown with your own layout. Open Customize Menu… to show, hide, or reorder controls, change their style and spacing, and choose what the menu-bar item shows."),
                        symbol: "slider.horizontal.3",
                        tint: model.menuCustomizationEnabled ? .on : .neutral)
                }
                .settingsAnchor("customize")
            } header: {
                GroupHeader(L("Custom layout"))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

/// The quick stop durations as removable chips, plus an Add menu.
private struct QuickStopEditor: View {
    @Binding var durations: [TimeInterval]
    let options: [TimeInterval]

    var body: some View {
        let free = options.filter { !durations.contains($0) }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(durations, id: \.self) { duration in
                HStack(spacing: 2) {
                    Text(verbatim: MenuBarContent.shortDuration(duration)).font(.system(size: 12.5))
                    Spacer(minLength: 2)
                    Button {
                        durations = durations.filter { $0 != duration }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Remove shortcut"))
                }
                .foregroundStyle(Color.panelAccentText)
                .padding(.leading, 10).padding(.trailing, 4)
                .frame(minHeight: 28)
                .background(Color.panelAccentSolid.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            if durations.count < PervigilSettings.maxQuickStopDurations && !free.isEmpty {
                Menu {
                    ForEach(free, id: \.self) { option in
                        Button(MenuBarContent.shortDuration(option)) {
                            durations = (durations + [option]).sorted()
                        }
                    }
                } label: {
                    Label(L("Add Shortcut"), systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .frame(maxWidth: .infinity, minHeight: 28)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A small picture of the menu bar and the panel over a wallpaper: the
/// countdown next to the icon, the panel's size, and its glass.
private struct MenuBarPreview: View {
    let showCountdown: Bool
    let expanded: Bool
    let clarity: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            wallpaper
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wifi").font(.system(size: 11, weight: .semibold))
                    HStack(spacing: 4) {
                        BrandMarkShape().fill(style: FillStyle(eoFill: true))
                            .frame(width: 11 * BrandMark.aspectRatio, height: 12)
                        if showCountdown {
                            Text(verbatim: "47:12").font(.system(size: 11, weight: .medium)).monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    Text(verbatim: Date.now.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .medium)).monospacedDigit()
                }
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(.bar)
                panel
                    .padding(.top, 6)
                    .padding(.trailing, 64)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 178)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Menu bar preview"))
        .animation(.snappy(duration: 0.25), value: expanded)
        .animation(.snappy(duration: 0.25), value: showCountdown)
    }

    private var panel: some View {
        let wash = scheme == .dark ? Color(white: 0.15) : Color(white: 0.97)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                MarkTile(state: .awake, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: L("Awake")).font(.system(size: 12, weight: .semibold))
                    Text(verbatim: "47:12").font(.system(size: 10.5)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            ForEach(0..<(expanded ? 5 : 1), id: \.self) { index in
                Capsule().fill(Color.primary.opacity(0.12))
                    .frame(width: [150, 110, 170, 90, 130][index], height: 6)
            }
        }
        .padding(10)
        .frame(width: 210, alignment: .leading)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Rectangle().fill(wash.opacity(0.92 - Double(clarity) / 100 * 0.7))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
    }

    private var wallpaper: some View {
        ZStack {
            LinearGradient(colors: scheme == .dark
                ? [Color(red: 0.11, green: 0.24, blue: 0.43), Color(red: 0.04, green: 0.05, blue: 0.08)]
                : [Color(red: 0.71, green: 0.83, blue: 0.98), Color(red: 0.78, green: 0.84, blue: 0.92)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            Capsule()
                .fill(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .leading, endPoint: .trailing))
                .frame(width: 320, height: 56)
                .offset(x: 160, y: 40)
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(scheme == .dark ? 0.12 : 0.6))
                .frame(width: 180, height: 96)
                .offset(x: -170, y: 20)
            Circle().fill(Color.green.opacity(0.8)).frame(width: 64).offset(x: 20, y: -30)
        }
    }
}
