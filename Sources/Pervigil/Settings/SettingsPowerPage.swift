import SwiftUI
import PervigilCore

/// The tiles on Lid & Battery. The selected tile shows its options below,
/// like the options drawer under the panel's guard tiles.
enum PowerTile: String, CaseIterable, Hashable {
    case lid, battery, heat, hotspot

    /// The tile that holds a search anchor, so a jump opens the right one.
    init?(anchor: String) {
        switch anchor {
        case "lid", "lidMode", "lidPolicy", "lowPower", "mute": self = .lid
        case "battery": self = .battery
        case "heat", "fanMinimum": self = .heat
        case "hotspot": self = .hotspot
        default: return nil
        }
    }
}

/// Lid & Battery (Sleep & Network on a desktop): run with the lid shut, and
/// the safety nets that let the Mac sleep when it should.
struct SettingsPowerPage: View {
    @Bindable var model: AppModel
    @Binding var tile: PowerTile
    let navigate: (SettingsPage, String?) -> Void
    /// Bumped when the lid control is clicked while it is busy.
    @State private var lidShakes = 0

    /// The fan boost strength a fresh "Boost fans first" starts at.
    private static let defaultFanBoostPercent = 80

    private var laptop: Bool { model.machineHasBattery }

    var body: some View {
        let tiles = laptop ? PowerTile.allCases : [.lid, .hotspot]
        Form {
            switch tiles.contains(tile) ? tile : .lid {
            case .lid: lidSection(tiles: tiles)
            case .battery: batterySection(tiles: tiles)
            case .heat: heatSection(tiles: tiles)
            case .hotspot: hotspotSection(tiles: tiles)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .animation(.snappy(duration: 0.25), value: tile)
        .animation(.snappy(duration: 0.25), value: model.batteryAutoPauseEnabled)
        .animation(.snappy(duration: 0.25), value: model.thermalSafety)
        .animation(.snappy(duration: 0.25), value: model.closedDisplayEnabled)
        .animation(.snappy(duration: 0.25), value: model.closedDisplayOnlyWhileBrewing)
        .animation(.snappy(duration: 0.25), value: model.closedLidLowPower)
        .onAppear { model.refreshClosedDisplay() }
    }

    // MARK: Header and tiles

    private func header(tiles: [PowerTile]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(page: .power, summary: laptop
                ? L("Run with the lid shut, and the safety nets that let the Mac sleep when it should. Pick a tile for its options.")
                : L("Override sleep on this Mac, and fall back to a hotspot when the network drops."))
            HStack(spacing: 8) {
                ForEach(tiles, id: \.self) { item in tileView(item) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private func tileView(_ item: PowerTile) -> some View {
        let values = model.panelStatus().tiles
        switch item {
        case .lid:
            GuardTileButton(
                title: laptop ? L("Lid closed") : L("Sleep override"),
                value: lidMode == .never ? (laptop ? L("Sleeps") : L("Off")) : values.lid,
                symbol: laptop ? "laptopcomputer" : "moon",
                isOn: lidMode != .never, selected: tile == .lid
            ) { tile = .lid }
        case .battery:
            GuardTileButton(
                title: L("Battery guard"), value: values.battery, symbol: "battery.25percent",
                isOn: model.batteryAutoPauseEnabled, warning: values.batteryWarning, selected: tile == .battery,
                toggle: Binding(get: { model.batteryAutoPauseEnabled }, set: { model.batteryAutoPauseEnabled = $0 })
            ) { tile = .battery }
        case .heat:
            GuardTileButton(
                title: L("Heat guard"), value: heatValue, symbol: "thermometer.medium",
                isOn: model.thermalSafety != nil, selected: tile == .heat,
                toggle: Binding(get: { model.thermalSafety != nil }, set: { model.thermalSafety = $0 ? ThermalSafetyConfig() : nil })
            ) { tile = .heat }
        case .hotspot:
            GuardTileButton(
                title: L("Hotspot"),
                value: model.hotspotConfig.enabled ? (model.hotspotConfig.ssid.isEmpty ? L("Choose network") : model.hotspotConfig.ssid) : L("Off"),
                symbol: "personalhotspot",
                isOn: model.hotspotConfig.enabled, selected: tile == .hotspot,
                toggle: Binding(get: { model.hotspotConfig.enabled }, set: {
                    var config = model.hotspotConfig; config.enabled = $0; model.hotspotConfig = config
                })
            ) { tile = .hotspot }
        }
    }

    private var heatValue: String {
        guard let config = model.thermalSafety else { return L("Off") }
        switch config.mode {
        case .pressure(let level): return level.label
        case .sensors(_, let celsius): return L("Above %d \u{00B0}C", Int(celsius))
        }
    }

    // MARK: Lid

    private enum LidMode: Hashable { case never, session, always }

    private var lidMode: LidMode {
        if model.closedDisplayOnlyWhileBrewing { return .session }
        return model.closedDisplayEnabled ? .always : .never
    }

    private var lidModeBinding: Binding<LidMode> {
        Binding(get: { lidMode }, set: { mode in
            switch mode {
            case .session:
                model.closedDisplayOnlyWhileBrewing = true
            case .always:
                if model.closedDisplayOnlyWhileBrewing { model.closedDisplayOnlyWhileBrewing = false }
                model.setClosedDisplay(true)
            case .never:
                if model.closedDisplayOnlyWhileBrewing { model.closedDisplayOnlyWhileBrewing = false }
                if model.closedDisplayEnabled { model.setClosedDisplay(false) }
            }
        })
    }

    @ViewBuilder
    private func lidSection(tiles: [PowerTile]) -> some View {
        let busy = model.closedDisplayBusy || model.closedDisplayAutoBusy
        Section {
            VStack(alignment: .leading, spacing: 10) {
                RowLabel(
                    title: laptop ? L("Keep awake with the lid closed") : L("Disable system sleep"),
                    subtitle: lidSubtitle,
                    symbol: laptop ? "laptopcomputer" : "moon",
                    tint: lidMode == .never ? .neutral : .on)
                Picker("", selection: lidModeBinding) {
                    Text(verbatim: L("Never")).tag(LidMode.never)
                    Text(verbatim: L("With each session")).tag(LidMode.session)
                    Text(verbatim: L("Always")).tag(LidMode.always)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(busy)
                .padding(.leading, 34)
                .accessibilityLabel(laptop ? L("Keep awake with the lid closed") : L("Disable system sleep"))
            }
            .settingsAnchor("lidMode")
            if busy && !model.helperInstalled {
                AdminAuthNote(purpose: laptop ? L("keep the Mac awake with the lid closed") : L("disable system sleep"))
            }
            if let error = model.closedDisplayError ?? model.closedDisplayAutoError {
                HelperFeatureNotice(model: model, message: error).font(.caption)
            }
            if lidMode == .always {
                RowNote(text: L("Stays on until you turn it off, even if Pervigil quits. Do not leave it on in a bag."), kind: .warning)
            }
            if model.closedLidNeedsHelper {
                // Automation never prompts on its own: say so, and offer the
                // one-click, this-run-only alternative next to the real fix.
                HStack {
                    RowNote(text: L("Turning on with sessions needs the administrator helper. Without it, Pervigil asks for your password only when you choose Allow Once, and that lasts until it quits."), kind: .locked)
                    Spacer(minLength: 8)
                    Button(L("Allow Once")) { model.allowClosedLidOnce() }
                        .buttonStyle(.link)
                        .disabled(busy)
                    Button(L("Set Up Helper…")) { navigate(.helper, nil) }.buttonStyle(.link)
                }
            } else if !model.helperInstalled {
                HStack {
                    RowNote(text: L("Without the administrator helper, macOS asks for your password once per app run."), kind: .locked)
                    Spacer(minLength: 8)
                    Button(L("Set Up Helper…")) { navigate(.helper, nil) }.buttonStyle(.link)
                }
            }
            if laptop && lidMode != .never {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: L("Screen when closed")).padding(.leading, 34)
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(ClosedLidDisplayPolicy.allCases, id: \.self) { policy in
                            PictureChoice(
                                value: policy,
                                selection: Binding(get: { model.closedLidDisplayPolicy }, set: { model.closedLidDisplayPolicy = $0 }),
                                title: policy.label
                            ) {
                                Image(systemName: policySymbol(policy)).font(.system(size: 22, weight: .light))
                            }
                        }
                    }
                    .padding(.leading, 34)
                    Text(verbatim: model.closedLidDisplayPolicy.explanation)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 34)
                    if let reason = model.displayDarkeningReason {
                        RowNote(text: reason)
                    }
                }
                .settingsAnchor("lidPolicy")
            }
            if laptop {
                lowPowerRows
                ToggleRow(
                    title: L("Mute built-in speakers while the lid is closed"),
                    subtitle: L("Mutes the built-in speakers with the lid closed and closed-display mode active. Headphones and other outputs keep playing. Unmutes when the lid opens or the mode ends, unless you had muted them yourself."),
                    symbol: model.closedLidMuteSpeakers ? "speaker.slash" : "speaker.wave.2",
                    isOn: Binding(get: { model.closedLidMuteSpeakers }, set: { model.closedLidMuteSpeakers = $0 }))
                    .settingsAnchor("mute")
            }
        } header: {
            GroupHeader(
                title: laptop ? L("Closed-display mode") : L("Disable sleep"),
                info: laptop
                    ? L("Normally a MacBook sleeps the moment you shut the lid unless a display is attached. This keeps it running with the lid shut and nothing plugged in, on power or battery. \u{201C}With each session\u{201D} turns it on when a keep-awake session starts and off when it ends or Pervigil quits, even after a crash. \u{201C}Always\u{201D} flips a system setting (pmset disablesleep) that stays in effect until you turn it off, so don't leave a Mac on battery in a bag. \u{201C}Screen when closed\u{201D} picks what the screen does: turn off, stay powered at zero brightness so a remote session stays live, or leave it alone. Both modes need administrator rights: silent with the administrator helper, otherwise macOS asks for your password once per app run.")
                    : L("Stops the Mac from sleeping at all. \u{201C}With each session\u{201D} turns it on while a keep-awake session runs and off when it ends or Pervigil quits, even after a crash. \u{201C}Always\u{201D} flips a system setting (pmset disablesleep) that stays in effect until you turn it off, even if Pervigil quits. The screen still turns off as usual. Both need administrator rights: silent with the administrator helper, otherwise macOS asks for your password once per app run.")
            ) { header(tiles: tiles) }
        } footer: {
            sectionFooter("Turn this on and then quit, and Pervigil asks whether to turn it off first.")
        }
    }

    private var lidSubtitle: String {
        switch lidMode {
        case .session: L("On while a session runs, off when it ends or Pervigil quits.")
        case .always: laptop ? L("Keeps running with the lid shut and no external display.") : L("Stops the Mac from sleeping at all until you turn it off.")
        case .never: laptop ? L("The Mac sleeps when you shut the lid.") : L("The Mac sleeps as usual.")
        }
    }

    private func policySymbol(_ policy: ClosedLidDisplayPolicy) -> String {
        switch policy {
        case .displayOff: "display"
        case .zeroBrightness: "sun.min"
        case .leaveAlone: "circle.slash"
        }
    }

    @ViewBuilder
    private var lowPowerRows: some View {
        let helperReady = model.helperInstalled && !model.helper.daemonOutdated
        ToggleRow(
            title: L("Low Power Mode while the lid is closed"),
            subtitle: L("Uses Low Power Mode with the lid closed and closed-display mode active. Battery only by default. Restores each power setting when the lid opens or the mode ends. Requires the administrator helper."),
            symbol: "leaf",
            isOn: Binding(get: { model.closedLidLowPower }, set: { model.closedLidLowPower = $0 }))
            .disabled(!helperReady && !model.closedLidLowPower)
            .settingsAnchor("lowPower")
        if model.closedLidLowPower {
            ToggleRow(title: L("Also use while plugged in"), indented: true,
                      isOn: Binding(get: { model.closedLidLowPowerOnAC }, set: { model.closedLidLowPowerOnAC = $0 }))
                .disabled(!helperReady && !model.closedLidLowPowerOnAC)
        }
        if model.closedLidLowPower || model.closedLidLowPowerController.failed {
            lowPowerStatus
        }
    }

    @ViewBuilder
    private var lowPowerStatus: some View {
        switch model.closedLidLowPowerController.status {
        case .off: EmptyView()
        case .needsHelper:
            RowNote(text: model.helperRecoveryHint ?? L("Install or update the administrator helper to use Low Power Mode."), kind: .locked)
        case .waitingForClosedDisplay:
            RowNote(text: L("Waiting for closed-display mode to be active."))
        case .waitingForLid:
            RowNote(text: L("Low Power Mode will turn on when the lid closes."))
        case .waitingForBattery:
            RowNote(text: L("Waiting for battery power. Enable plugged-in use to include the power adapter."))
        case .switching:
            RowNote(text: L("Updating Low Power Mode…"))
        case .active:
            RowNote(text: L("Low Power Mode is active."), kind: .success)
        case .failed:
            HelperFeatureNotice(model: model, message: L("Could not update Low Power Mode. Pervigil will retry."), helperOnly: true)
                .font(.caption)
        }
    }

    // MARK: Battery

    @ViewBuilder
    private func batterySection(tiles: [PowerTile]) -> some View {
        let charge = model.powerReading.percentage
        let warning = model.panelStatus().tiles.batteryWarning
        Section {
            ToggleRow(
                title: L("Pause on low battery"),
                subtitle: charge.map { L("Now %d%%. Lets the Mac sleep below %d%%.", $0, model.pauseBelowBatteryPercent) },
                symbol: "battery.25percent",
                onTint: warning ? .warning : .on,
                isOn: Binding(get: { model.batteryAutoPauseEnabled }, set: { model.batteryAutoPauseEnabled = $0 }))
                .settingsAnchor("battery")
            if model.batteryAutoPauseEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    if let charge {
                        ChargeMeter(charge: charge, threshold: model.pauseBelowBatteryPercent)
                    }
                    LabeledContent(L("Below")) {
                        BatteryThresholdSlider(percent: Binding(
                            get: { model.pauseBelowBatteryPercent },
                            set: { model.pauseBelowBatteryPercent = $0 }))
                    }
                }
                .padding(.leading, 34)
            }
        } header: {
            GroupHeader(
                title: L("Battery guard"),
                info: L("A safety net for a session you forget about. If the charge falls this low, Pervigil pauses the session and lets the Mac sleep, even mid-session, and tells you why in a notification. The menu-bar icon shows a yellow band while paused for low battery. Plugging in resumes it on its own. This is the same slider as the one in the menu, so the two always agree.")
            ) { header(tiles: tiles) }
        } footer: {
            sectionFooter("Lets the Mac sleep once charge drops below this level, and switches off closed-display mode so a lid-closed Mac can sleep too.")
        }
    }

    // MARK: Heat

    @ViewBuilder
    private func heatSection(tiles: [PowerTile]) -> some View {
        let helperReady = model.helperInstalled
        Section {
            ToggleRow(
                title: L("Pause when running hot"),
                subtitle: L("If the Mac runs hot with the lid closed, the session pauses so it can sleep and cool down."),
                symbol: "thermometer.medium",
                isOn: Binding(get: { model.thermalSafety != nil }, set: { model.thermalSafety = $0 ? ThermalSafetyConfig() : nil }))
                .settingsAnchor("heat")
            if let config = model.thermalSafety {
                EscalationChain(
                    sustain: config.sustainSeconds,
                    boost: helperReady && model.machineHasFans ? config.fanBoostPercent : nil)
                    .padding(.leading, 34)
                Picker(selection: Binding(
                    get: { if case .sensors = config.mode { return 1 } else { return 0 } },
                    set: { kind in
                        var updated = config
                        updated.mode = kind == 1
                            ? .sensors(ids: [], celsius: ThermalSafetyConfig.celsiusRange.upperBound - 15)
                            : .pressure(atOrAbove: .serious)
                        model.thermalSafety = updated
                    })) {
                    Text("System thermal pressure").tag(0)
                    Text("Temperature sensors").tag(1)
                } label: {
                    RowLabel(title: L("Watch"), indented: true)
                }
                switch config.mode {
                case .pressure(let level):
                    Picker(selection: Binding(
                        get: { level },
                        set: { newLevel in
                            var updated = config
                            updated.mode = .pressure(atOrAbove: newLevel)
                            model.thermalSafety = updated
                        })) {
                        ForEach([ThermalPressureLevel.fair, .serious, .critical], id: \.self) { level in
                            Text(verbatim: level.label).tag(level)
                        }
                    } label: {
                        RowLabel(title: L("At or above"), indented: true)
                    }
                case .sensors(let ids, let celsius):
                    ThermalSensorPicker(model: model, selectedIDs: Binding(
                        get: { ids },
                        set: { newIDs in
                            var updated = config
                            updated.mode = .sensors(ids: newIDs, celsius: celsius)
                            model.thermalSafety = updated
                        }))
                        .padding(.leading, 34)
                    LabeledContent {
                        TemperatureThresholdSlider(celsius: Binding(
                            get: { celsius },
                            set: { newCelsius in
                                var updated = config
                                updated.mode = .sensors(ids: ids, celsius: newCelsius)
                                model.thermalSafety = updated
                            }))
                    } label: {
                        RowLabel(title: L("Above"), indented: true)
                    }
                }
                Picker(selection: Binding(
                    get: { Int(config.sustainSeconds) },
                    set: { seconds in
                        var updated = config
                        updated.sustainSeconds = TimeInterval(seconds)
                        model.thermalSafety = updated
                    })) {
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                } label: {
                    RowLabel(title: L("Sustained for"), indented: true)
                }
                if helperReady {
                    if model.machineHasFans {
                        ToggleRow(title: L("Boost fans first"), indented: true, isOn: Binding(
                            get: { config.fanBoostPercent != nil },
                            set: { boost in
                                var updated = config
                                updated.fanBoostPercent = boost ? Self.defaultFanBoostPercent : nil
                                model.thermalSafety = updated
                            }))
                        if let percent = config.fanBoostPercent {
                            LabeledContent {
                                FanBoostSlider(percent: Binding(
                                    get: { percent },
                                    set: { newPercent in
                                        var updated = config
                                        updated.fanBoostPercent = newPercent
                                        model.thermalSafety = updated
                                    }))
                            } label: {
                                RowLabel(title: L("To"), indented: true)
                            }
                            FanTestRows(model: model)
                        }
                    }
                } else {
                    ThermalHelperLockedRow(model: model)
                }
            }
            if model.machineHasFans {
                ToggleRow(
                    title: L("Minimum fan speed with the lid closed"),
                    subtitle: L("Applies only with the lid closed and closed-display mode active. Heat boost can raise this floor; boost and pause settings above stay independent. Returns fan control to the system when the mode ends."),
                    symbol: "fan",
                    isOn: Binding(
                        get: { model.closedLidMinimumFanPercent != nil },
                        set: { model.closedLidMinimumFanPercent = $0 ? ClosedLidFanFloor.defaultPercent : nil }))
                    .disabled((!model.helperInstalled || model.helper.daemonOutdated) && model.closedLidMinimumFanPercent == nil)
                    .settingsAnchor("fanMinimum")
                if let percent = model.closedLidMinimumFanPercent {
                    LabeledContent {
                        FanBoostSlider(percent: Binding(
                            get: { percent }, set: { model.closedLidMinimumFanPercent = $0 }
                        ), percentRange: ClosedLidFanFloor.percentRange)
                    } label: {
                        RowLabel(title: L("Minimum"), indented: true)
                    }
                    if let hint = model.helperRecoveryHint {
                        RowNote(text: hint)
                    } else if model.fanFloor.failed {
                        HelperFeatureNotice(model: model, message: L("Fan minimum unavailable. Thermal protection remains unchanged."), helperOnly: true)
                            .font(.caption)
                    } else if let active = model.fanFloor.holdingPercent {
                        RowNote(text: L("Minimum fan speed: %d%%", active), kind: .success)
                    }
                }
                if model.thermalSafety == nil && !model.helperInstalled {
                    ThermalHelperLockedRow(model: model)
                }
            }
        } header: {
            GroupHeader(
                title: L("Heat guard"),
                info: L("A safety net for a Mac left running with the lid closed, slid into a bag with a session still holding it awake. It acts only in that trapped state: lid shut, with \u{201C}Keep awake with the lid closed\u{201D} overriding sleep. Watch macOS's own thermal pressure (works everywhere, \u{201C}Serious\u{201D} is where throttling bites) or specific temperature sensors, and if the reading stays over the threshold for the chosen time, Pervigil escalates: first, optionally, it boosts the fans (never below what the system chose, needs the administrator helper), and if it stays hot for the same time again, it pauses the session and switches the sleep override off, so the Mac can finally sleep and cool, telling you why in a notification. Opening the lid, or readings recovering, undoes everything: fan control returns to the system, the override comes back, and the session resumes. Die sensors on modern Macs routinely run at 90-100 \u{00B0}C under load, so thresholds around 95-100 \u{00B0}C are sensible.")
            ) { header(tiles: tiles) }
        }
    }

    // MARK: Hotspot

    @ViewBuilder
    private func hotspotSection(tiles: [PowerTile]) -> some View {
        Section {
            HStack(spacing: 8) {
                ForEach(tiles, id: \.self) { item in tileView(item) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .settingsAnchor("hotspot")
        } header: {
            PageHeader(page: .power, summary: laptop
                ? L("Run with the lid shut, and the safety nets that let the Mac sleep when it should. Pick a tile for its options.")
                : L("Override sleep on this Mac, and fall back to a hotspot when the network drops."))
        }
        HotspotPreferencesSection(model: model)
    }
}

/// The battery charge against the guard's limit, so "how close am I" needs
/// no arithmetic.
private struct ChargeMeter: View {
    let charge: Int
    let threshold: Int

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.06))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((charge - threshold <= 5 ? Color.panelAmberDot : Color.panelGreenText).opacity(0.18))
                    .frame(width: width * CGFloat(charge) / 100)
                Text(verbatim: L("%d%% now", charge))
                    .font(.system(size: 11.5, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(charge - threshold <= 5 ? Color.panelAmberText : Color.panelGreenText)
                    .padding(.leading, 8)
                Rectangle().fill(Color.panelAmberDot)
                    .frame(width: 2, height: 26)
                    .offset(x: width * CGFloat(threshold) / 100 - 1)
            }
        }
        .frame(height: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("%d%% now", charge))
    }
}

/// The heat guard's steps as a chain: hot for a while, fans up, still hot,
/// pause and sleep, and everything restored when the lid opens.
private struct EscalationChain: View {
    let sustain: TimeInterval
    let boost: Int?

    var body: some View {
        let wait = sustain >= 60 ? SettingsFormat.short(sustain) : L("%d s", Int(sustain))
        HStack(spacing: 5) {
            pill(L("Hot for %@", wait), tint: .neutral)
            arrow
            if let boost {
                pill(L("Fans to %d%%", boost), tint: .on)
                arrow
                pill(L("Still hot"), tint: .neutral)
                arrow
            }
            pill(L("Pause and sleep"), tint: .warning)
            arrow
            pill(L("Lid opens: restored"), tint: .met)
        }
        .accessibilityElement(children: .combine)
    }

    private var arrow: some View {
        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.tertiary)
    }

    private func pill(_ text: String, tint: SettingsTint) -> some View {
        StatusPill(text: text, tint: tint).lineLimit(1).fixedSize()
    }
}
