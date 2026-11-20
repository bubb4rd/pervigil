import SwiftUI
import PervigilCore

// The Settings window's building blocks (see design/concepts/settings/opus).
// Pages stay grouped `Form`s so macOS spacing, focus, and VoiceOver come for
// free; these views give each row the panel's grammar: a small icon tile
// whose tint carries the state.

// MARK: - State icon

/// What an icon tile says about its row. Amber is kept for "about to stop or
/// stopped against your wishes", as in the panel.
enum SettingsTint: Equatable {
    case neutral, on, met, warning

    var fill: Color {
        switch self {
        case .neutral: Color.primary.opacity(0.07)
        case .on: Color.panelAccentSolid.opacity(0.14)
        case .met: Color.panelGreenText.opacity(0.15)
        case .warning: Color.panelAmberDot.opacity(0.16)
        }
    }

    var ink: Color {
        switch self {
        case .neutral: Color.secondary
        case .on: Color.panelAccentText
        case .met: Color.panelGreenText
        case .warning: Color.panelAmberText
        }
    }
}

/// The 24 pt rounded tile in front of a settings row.
struct StateIcon: View {
    let symbol: String
    var tint: SettingsTint = .neutral
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .medium))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(tint.ink)
            .frame(width: size, height: size)
            .background(tint.fill, in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
            .animation(.easeInOut(duration: 0.25), value: tint)
            .accessibilityHidden(true)
    }
}

/// The label of a settings row: icon tile, title, and an optional quieter
/// line under it. Pass it as the label of a `Toggle`, `Picker`, or
/// `LabeledContent` so the grouped Form lays the control out natively.
struct RowLabel: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    var tint: SettingsTint = .neutral
    /// Amber subtitle, for a warning about this row.
    var warning = false
    /// An option under a row with an icon: indent to line up with its title.
    var indented = false

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                StateIcon(symbol: symbol, tint: tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.caption)
                        .foregroundStyle(warning ? AnyShapeStyle(Color.panelAmberText) : AnyShapeStyle(.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
            }
        }
        .padding(.leading, indented ? 34 : 0)
    }
}

/// A switch row: icon, title, subtitle, switch. The icon turns accent while on.
struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    var onTint: SettingsTint = .on
    var indented = false
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            RowLabel(title: title, subtitle: subtitle, symbol: symbol, tint: isOn ? onTint : .neutral, indented: indented)
        }
        .toggleStyle(.switch)
    }
}

/// A one-line note inside a group: info, a warning, or a success.
struct RowNote: View {
    enum Kind { case info, warning, success, locked }
    let text: String
    var kind: Kind = .info
    var indented = true

    var body: some View {
        Label {
            Text(verbatim: text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .font(.caption)
        .foregroundStyle(kind == .info || kind == .locked ? AnyShapeStyle(.secondary) : AnyShapeStyle(color))
        .padding(.leading, indented ? 34 : 0)
    }

    private var symbol: String {
        switch kind {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .success: "checkmark.circle.fill"
        case .locked: "lock"
        }
    }

    private var color: Color {
        switch kind {
        case .info, .locked: .secondary
        case .warning: .panelAmberText
        case .success: .panelGreenText
        }
    }
}

// MARK: - Page header

/// The top of every page: the page's tile, its name, and one sentence on
/// what it is for, with an optional control on the right (Triggers' master
/// switch). Sits in the first section's header so it scrolls with the page.
struct PageHeader<Accessory: View>: View {
    let page: SettingsPage
    let summary: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 14) {
            SidebarTile(page: page, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: page.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(verbatim: summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            accessory
        }
        .padding(.bottom, 14)
        .textCase(nil)
    }
}

extension PageHeader where Accessory == EmptyView {
    init(page: SettingsPage, summary: String) {
        self.init(page: page, summary: summary) { EmptyView() }
    }
}

/// A section header: optional lead content above it (the page header, tiles,
/// a preview), then the group title with its info button.
struct GroupHeader<Lead: View>: View {
    let title: String?
    var info: String? = nil
    @ViewBuilder var lead: Lead

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            lead
            if let title {
                HStack(spacing: 4) {
                    Text(verbatim: title)
                    if let info { InfoButton(text: info) }
                }
            }
        }
        .textCase(nil)
    }
}

extension GroupHeader where Lead == EmptyView {
    init(_ title: String, info: String? = nil) {
        self.init(title: title, info: info) { EmptyView() }
    }
}

// MARK: - Tiles

/// A Control Center tile, as in the panel's guards: icon, name, value, and
/// an optional small switch. Blue while on, amber near a limit, outlined
/// while selected (it is showing its options below).
struct GuardTileButton: View {
    let title: String
    let value: String
    let symbol: String
    let isOn: Bool
    var warning = false
    var selected = false
    var toggle: Binding<Bool>? = nil
    var wide = false
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Group {
                if wide {
                    HStack(spacing: 10) { icon; text; Spacer(minLength: 44) }
                } else {
                    VStack(alignment: .leading, spacing: 8) { icon; text }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: wide ? 64 : 86, maxHeight: wide ? nil : .infinity, alignment: wide ? .leading : .topLeading)
            .background(background, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: selected ? 2 : 0.5))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .overlay(alignment: wide ? .trailing : .topTrailing) {
            if let toggle {
                Toggle("", isOn: toggle)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(wide ? .small : .mini)
                    .accessibilityLabel(Text(verbatim: title))
                    .padding(wide ? 12 : 9)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(.easeInOut(duration: 0.2), value: isOn)
        .animation(.easeInOut(duration: 0.2), value: warning)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 11, style: .continuous) }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(isOn || warning ? Color.white : Color.secondary)
            .frame(width: 28, height: 28)
            .background(iconFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.primary)
            Text(verbatim: value)
                .font(.system(size: 11.5))
                .foregroundStyle(warning ? Color.panelAmberText : isOn ? Color.panelAccentText : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private var iconFill: Color {
        warning ? .panelAmberDot : isOn ? .panelAccentSolid : Color.primary.opacity(0.07)
    }

    private var background: Color {
        warning ? Color.panelAmberDot.opacity(0.13) : isOn ? Color.panelAccentSolid.opacity(0.11) : Color.primary.opacity(0.035)
    }

    private var border: Color {
        if selected { return .panelAccentSolid }
        return warning ? Color.panelAmberDot.opacity(0.35) : isOn ? Color.panelAccentSolid.opacity(0.3) : Color.primary.opacity(0.09)
    }
}

// MARK: - Choices

/// A grid of equal chips, one selected, like the panel's duration chips.
struct ChipPicker<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var columns: Int? = nil

    var body: some View {
        let count = columns ?? options.count
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: count), spacing: 6) {
            ForEach(options, id: \.value) { option in
                let chosen = option.value == selection
                Button { selection = option.value } label: {
                    Text(verbatim: option.label)
                        .font(.system(size: 12.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .foregroundStyle(chosen ? Color.white : Color.primary)
                        .background(chosen ? Color.panelAccentSolid : Color.primary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle(scale: 0.96))
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
    }
}

/// A card with a small picture over a name and an optional line: the lid
/// policies, the end-of-session actions, display resolutions.
struct PictureChoice<Value: Hashable, Picture: View>: View {
    let value: Value
    @Binding var selection: Value
    let title: String
    var detail: String? = nil
    var centered = false
    @ViewBuilder var picture: Picture

    var body: some View {
        let chosen = value == selection
        Button { selection = value } label: {
            VStack(alignment: centered ? .center : .leading, spacing: 6) {
                picture
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(chosen ? Color.panelAccentText : Color.secondary)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(verbatim: title)
                    .font(.system(size: 12, weight: .semibold))
                    .multilineTextAlignment(centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(verbatim: detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: centered ? .top : .topLeading)
            .padding(8)
            .background(chosen ? Color.panelAccentSolid.opacity(0.12) : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(chosen ? Color.panelAccentSolid : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .animation(.easeInOut(duration: 0.15), value: chosen)
    }
}

/// A small capsule label: "Ready", "Password saved", "Experimental".
struct StatusPill: View {
    let text: String
    var tint: SettingsTint = .neutral

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint == .neutral ? Color.secondary : tint.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tint == .neutral ? Color.primary.opacity(0.08) : tint.fill, in: Capsule())
    }
}

// MARK: - Mark tile

/// The brand mark on its tile, without the panel's button behavior: blue
/// while awake, grey while the Mac can sleep, amber while paused.
struct MarkTile: View {
    var state: PanelStatus.State = .awake
    var held = false
    var size: CGFloat = 28
    /// The brand gradient (app icon look) instead of the state colors.
    var brand = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).fill(background)
            ZStack {
                MarkPart(part: .body).fill(style: FillStyle(eoFill: true))
                MarkPart(part: .bar(level: 1))
                MarkPart(part: .inner).opacity(held ? 1 : 0)
            }
            .frame(width: size * 0.52 * BrandMark.aspectRatio, height: size * 0.52)
            .foregroundStyle(ink)
        }
        .frame(width: size, height: size)
        .shadow(color: brand || state == .awake ? Color.panelTileBottom.opacity(0.3) : .clear, radius: size * 0.12, y: size * 0.05)
        .accessibilityHidden(true)
    }

    private var background: AnyShapeStyle {
        if brand {
            return AnyShapeStyle(LinearGradient(colors: [.brandMarkTop, .brandMarkBottom], startPoint: .top, endPoint: .bottom))
        }
        switch state {
        case .awake: return AnyShapeStyle(LinearGradient(colors: [.panelTileTop, .panelTileBottom], startPoint: .top, endPoint: .bottom))
        case .paused: return AnyShapeStyle(Color.panelAmberDot.opacity(0.18))
        case .canSleep: return AnyShapeStyle(Color.primary.opacity(0.1))
        }
    }

    private var ink: Color {
        if brand { return .white }
        switch state {
        case .awake: return .white
        case .paused: return .panelAmberText
        case .canSleep: return .secondary
        }
    }
}

// MARK: - Formatting

enum SettingsFormat {
    /// "15 min", "1 h", "1 h 30 min", for chips.
    static func short(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return L("%d min", minutes) }
        if minutes % 60 == 0 { return L("%d h", minutes / 60) }
        return L("%d h %d min", minutes / 60, minutes % 60)
    }

    /// "47:12" or "1:02:05".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
