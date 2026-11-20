import SwiftUI
import PervigilCore

/// Closed Lid, Battery Guard, Display, and Stay Active as tiles: the only
/// cards in the panel. The tile body toggles; its chevron, a separate button,
/// opens that tile's options in one drawer under the grid.
struct PanelGuardsSection: View {
    @Bindable var model: AppModel
    let tiles: GuardTileValues

    enum Tile: Hashable { case lid, battery, display, stayActive }
    @State private var open: Tile?
    @State private var lidShakes = 0

    private var session: SessionController { model.session }

    var body: some View {
        VStack(spacing: 7) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 7)], spacing: 7) {
                ForEach(available, id: \.self) { tile in
                    GuardTile(
                        title: title(tile), value: value(tile), symbol: symbol(tile),
                        isOn: isOn(tile), warning: tile == .battery && tiles.batteryWarning,
                        isOpen: open == tile,
                        toggle: { toggle(tile) },
                        toggleOptions: { withAnimation(.snappy(duration: 0.25)) { open = open == tile ? nil : tile } })
                        .disabled(tile == .lid && (model.closedDisplayBusy || model.closedDisplayAutoBusy))
                }
            }
            if let open, available.contains(open) {
                drawer(open)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var available: [Tile] {
        model.machineHasBattery ? [.lid, .battery, .display, .stayActive] : [.lid, .display, .stayActive]
    }

    private func title(_ tile: Tile) -> String {
        switch tile {
        case .lid: model.machineHasBattery ? L("Closed Lid") : L("Never Sleep")
        case .battery: L("Battery Guard")
        case .display: L("Display")
        case .stayActive: L("Stay Active")
        }
    }

    private func value(_ tile: Tile) -> String {
        switch tile {
        case .lid: tiles.lid
        case .battery: tiles.battery
        case .display: tiles.display
        case .stayActive: tiles.stayActive
        }
    }

    private func symbol(_ tile: Tile) -> String {
        switch tile {
        case .lid: model.machineHasBattery ? "laptopcomputer" : "moon.zzz"
        case .battery: "battery.50percent"
        case .display: "display"
        case .stayActive: "cursorarrow.motionlines"
        }
    }

    private func isOn(_ tile: Tile) -> Bool {
        switch tile {
        case .lid: model.closedDisplayEnabled || model.closedDisplayOnlyWhileBrewing
        case .battery: model.batteryAutoPauseEnabled
        case .display: session.options.preventDisplaySleep
        case .stayActive: model.simulateUserActivity
        }
    }

    private func toggle(_ tile: Tile) {
        switch tile {
        case .lid:
            if isOn(.lid) {
                if model.closedDisplayOnlyWhileBrewing { model.closedDisplayOnlyWhileBrewing = false }
                if model.closedDisplayEnabled { model.setClosedDisplay(false) }
            } else {
                model.setClosedDisplay(true)
            }
        case .battery: model.batteryAutoPauseEnabled.toggle()
        case .display: model.updateOptions { $0.preventDisplaySleep.toggle() }
        case .stayActive: model.simulateUserActivity.toggle()
        }
    }

    // MARK: Drawers

    @ViewBuilder
    private func drawer(_ tile: Tile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch tile {
            case .lid: lidOptions
            case .battery: batteryOptions
            case .display: displayOptions
            case .stayActive: stayActiveOptions
            }
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .padding(.horizontal, 2)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var lidOptions: some View {
        switchRow("Only while awake", isOn: Binding(
            get: { model.closedDisplayOnlyWhileBrewing },
            set: { model.closedDisplayOnlyWhileBrewing = $0 }
        ), info: model.machineHasBattery
            ? L("Turns closed-display mode on when a keep-awake session starts and off when it ends or Pervigil quits.")
            : L("Turns the sleep override on when a keep-awake session starts and off when it ends or Pervigil quits."))
        .disabled(model.closedDisplayAutoBusy)
        if model.machineHasBattery {
            Picker(L("If the lid shuts"), selection: Binding(
                get: { model.closedLidDisplayPolicy },
                set: { model.closedLidDisplayPolicy = $0 }
            )) {
                ForEach(ClosedLidDisplayPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
        }
        if model.closedDisplayBusy || (model.closedDisplayAutoBusy && !model.helperInstalled) {
            AdminAuthNote(purpose: model.machineHasBattery
                ? L("keep the Mac awake with the lid closed") : L("disable system sleep"))
        }
        if let error = model.closedDisplayError ?? model.closedDisplayAutoError {
            HelperFeatureNotice(model: model, message: error).font(.system(size: 11))
        }
        Text(model.closedDisplayEnabled
            ? (model.machineHasBattery
                ? L("Stays awake on battery too; the display turns off when the lid closes. Turn it off before putting it in a bag.")
                : L("The Mac won't sleep at all until you turn this off. The display still sleeps as usual."))
            : model.closedLidDisplayPolicy.explanation)
            .font(.system(size: 11))
            .foregroundStyle(model.closedDisplayEnabled && model.machineHasBattery ? Color.panelAmberText : Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var batteryOptions: some View {
        let power = model.powerReading
        if let percent = power.percentage {
            BatteryMeter(percent: percent, threshold: model.pauseBelowBatteryPercent,
                         pluggedIn: power.provider != .battery, warning: tiles.batteryWarning)
        }
        BatteryThresholdSlider(percent: Binding(
            get: { model.pauseBelowBatteryPercent },
            set: { model.pauseBelowBatteryPercent = $0 }
        ))
        Text("Lets the Mac sleep once battery charge drops below this level, even mid-session, so it doesn't run flat.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var displayOptions: some View {
        if model.brightnessSupported {
            switchRow("Dim the display when idle", isOn: Binding(
                get: { session.options.dimDisplayAfter != nil },
                set: { on in model.updateOptions {
                    $0.dimDisplayAfter = on ? ($0.dimDisplayAfter ?? 5 * 60) : nil
                    if on { $0.allowScreenSaverAfter = nil }
                }}
            ))
        }
        switchRow("Allow screen saver after", isOn: Binding(
            get: { session.options.allowScreenSaverAfter != nil },
            set: { on in model.updateOptions {
                $0.allowScreenSaverAfter = on ? ($0.allowScreenSaverAfter ?? 5 * 60) : nil
                if on { $0.dimDisplayAfter = nil }
            }}
        ))
        .disabled(!session.options.preventDisplaySleep)
    }

    @ViewBuilder
    private var stayActiveOptions: some View {
        Picker(L("Method"), selection: Binding(
            get: { model.activitySimulationMethod },
            set: { model.activitySimulationMethod = $0 }
        )) {
            ForEach(ActivitySimulationMethod.allCases, id: \.self) { Text($0.menuLabel).tag($0) }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        Text("Reports activity so you stay present in apps that have their own idle timeout.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One guard: the icon on the left in a rounded square that fills with the
/// accent when on (amber near the battery limit), the name and its state,
/// and a chevron that opens the options.
private struct GuardTile: View {
    let title: String
    let value: String
    let symbol: String
    let isOn: Bool
    let warning: Bool
    let isOpen: Bool
    let toggle: () -> Void
    let toggleOptions: () -> Void

    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: toggle) {
                HStack(spacing: 7) {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(isOn || warning ? Color.white : Color.secondary)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(iconFill))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        Text(value)
                            .font(.system(size: 11, weight: isOn || warning ? .medium : .regular))
                            .foregroundStyle(valueInk)
                            .lineLimit(1)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 6)
                .padding(.trailing, 19)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle(scale: 0.98))
            .accessibilityLabel(title)
            .accessibilityValue(value)
            .accessibilityAddTraits(isOn ? .isSelected : [])

            Button(action: toggleOptions) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .frame(width: 18, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.trailing, 2)
            .help(L("Options"))
            .accessibilityLabel(L("%@ options", title))
            .accessibilityAddTraits(isOpen ? .isSelected : [])
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(cardFill))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(cardStroke, lineWidth: 1))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.13), value: hovering)
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }

    private var iconFill: Color {
        if warning { return .panelAmberDot }
        return isOn ? .panelAccentSolid : Color.primary.opacity(0.1)
    }
    private var valueInk: Color {
        if warning { return .panelAmberText }
        return isOn ? .panelAccentText : .secondary
    }
    private var cardFill: Color {
        if warning { return Color.panelAmberDot.opacity(0.15) }
        if isOn { return Color.panelAccentSolid.opacity(0.13) }
        return Color.primary.opacity(hovering ? 0.08 : 0.05)
    }
    private var cardStroke: Color {
        if warning { return Color.panelAmberDot.opacity(0.35) }
        if isOn { return Color.panelAccentSolid.opacity(0.3) }
        return Color.primary.opacity(0.08)
    }
}

/// The charge against the guard's cutoff, in the battery drawer.
private struct BatteryMeter: View {
    let percent: Int
    let threshold: Int
    let pluggedIn: Bool
    let warning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pluggedIn ? L("Charge %d%%, plugged in", percent) : L("Charge %d%%", percent))
                Spacer()
                Text(L("Sleeps below %d%%", threshold))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(warning ? Color.panelAmberDot : Color.panelGreenText)
                        .frame(width: geo.size.width * CGFloat(min(100, max(0, percent))) / 100)
                    Rectangle().fill(Color.primary)
                        .frame(width: 2, height: 11)
                        .offset(x: geo.size.width * CGFloat(threshold) / 100 - 1)
                }
            }
            .frame(height: 5)
        }
        .accessibilityElement(children: .combine)
    }
}
