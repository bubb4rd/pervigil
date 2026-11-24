import SwiftUI
import PervigilCore

/// Keep Awake: what a session holds (the Mac, the display), and whether other
/// apps still see you as present.
struct SettingsKeepAwakePage: View {
    @Bindable var model: AppModel

    private var session: SessionController { model.session }

    /// Idle waits offered by "Only after idle".
    private static let idleChoices = [1, 2, 3, 4, 5, 10, 15, 20, 30]
    /// How long with no input before dim-don't-sleep dims the panel.
    private static let dimDefaultDelay: TimeInterval = 300

    var body: some View {
        let sys = session.options.preventSystemSleep
        let disp = session.options.preventDisplaySleep
        Form {
            Section {
                HStack(spacing: 8) {
                    GuardTileButton(
                        title: L("Prevent system sleep"), value: sys ? L("Stays awake") : L("Sleeps"),
                        symbol: "laptopcomputer", isOn: sys, toggle: optionBinding(\.preventSystemSleep), wide: true
                    ) { optionBinding(\.preventSystemSleep).wrappedValue.toggle() }
                    .settingsAnchor("system")
                    GuardTileButton(
                        title: L("Prevent display sleep"), value: disp ? L("Stays on") : L("Turns off"),
                        symbol: disp ? "sun.max" : "sun.min", isOn: disp, toggle: optionBinding(\.preventDisplaySleep), wide: true
                    ) { optionBinding(\.preventDisplaySleep).wrappedValue.toggle() }
                    .settingsAnchor("display")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                GroupHeader(title: L("Keep awake"), info: L("Two independent switches. Preventing system sleep keeps the Mac itself running: work finishes, downloads complete, and it stays reachable over the network, while the screen is still free to turn off. Preventing display sleep also keeps the screen lit, which is what you want for a dashboard or a video, and what drains a battery fastest. Most setups want system sleep prevented and display sleep left alone.")) {
                    PageHeader(page: .keepAwake, summary: L("What a session holds, and whether other apps still see you as present."))
                }
            } footer: {
                Text(verbatim: sentence(sys: sys, disp: disp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if disp && model.brightnessSupported {
                Section {
                    ToggleRow(
                        title: L("Dim the display when idle"),
                        subtitle: L("Instead of holding the screen at full brightness, lower it to its dimmest after a few minutes with no input, then bring it back the moment you return. The display stays awake, just dark: kinder to the panel and the battery on long overnight sessions."),
                        symbol: "sun.min",
                        isOn: dimBinding)
                        .settingsAnchor("dim")
                } header: {
                    GroupHeader(L("Display"))
                }
            }

            Section {
                ToggleRow(
                    title: L("Keep me active"),
                    subtitle: L("Reports activity so you stay present in apps that have their own idle timeout."),
                    symbol: "person",
                    isOn: Binding(get: { model.simulateUserActivity }, set: { model.simulateUserActivity = $0 }))
                    .settingsAnchor("presence")
                if model.simulateUserActivity {
                    ForEach(ActivitySimulationMethod.allCases, id: \.self) { method in
                        MethodRow(
                            title: method.menuLabel,
                            detail: methodDetail(method),
                            selected: model.activitySimulationMethod == method
                        ) { model.activitySimulationMethod = method }
                    }
                    if model.activitySimulationMethod == .specifiedKey {
                        LabeledContent {
                            PresenceKeyRecorder(key: Binding(
                                get: { model.activitySimulationKey },
                                set: { model.activitySimulationKey = $0 }))
                        } label: {
                            RowLabel(title: L("Key"),
                                     subtitle: L("To keep browsers from showing focus rings, record F13 to F20 while holding Control, Option, or Command."),
                                     indented: true)
                        }
                    }
                    if model.activitySimulationMethod.needsAccessibility && !model.accessibilityTrusted {
                        HStack {
                            RowNote(text: L("Needs Accessibility for this method."), kind: .warning)
                            Spacer(minLength: 8)
                            Button(L("Open Settings")) { model.openAccessibilitySettings() }
                        }
                    }
                    LabeledContent {
                        HStack(spacing: 8) {
                            if model.activityPokeIdleMinutes != nil {
                                Picker("", selection: Binding(
                                    get: { model.activityPokeIdleMinutes ?? 3 },
                                    set: { model.activityPokeIdleMinutes = $0 })) {
                                    ForEach(Self.idleChoices, id: \.self) { minutes in
                                        Text(L("%d min", minutes)).tag(minutes)
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                                .accessibilityLabel(L("Wait"))
                            }
                            Toggle("", isOn: Binding(
                                get: { model.activityPokeIdleMinutes != nil },
                                set: { model.activityPokeIdleMinutes = $0 ? 3 : nil }))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityLabel(L("Only after idle"))
                        }
                    } label: {
                        RowLabel(
                            title: L("Only after idle"),
                            subtitle: model.activityPokeIdleMinutes.map { L("Only after %d min idle, never while a game is frontmost.", $0) },
                            indented: true)
                    }
                    Toggle(isOn: optionBinding(\.activityOnlyWhileBrewing)) {
                        RowLabel(
                            title: L("Only during keep-awake"),
                            subtitle: session.options.activityOnlyWhileBrewing ? nil : L("Also runs between sessions, which can keep the Mac from sleeping."),
                            warning: true,
                            indented: true)
                    }
                    .toggleStyle(.switch)
                }
            } header: {
                GroupHeader(L("Presence"), info: L("Keeping the Mac awake stops it sleeping, but that does not keep you active in other software. Meeting and chat apps, remote desktop and VDI, cloud gaming, and many other tools still apply their own idle timeout: they mark you away, disconnect, or end the session. This reports activity so you stay present. The default method needs no extra permission. Some software only notices a real key or mouse, so you can pick F15, Shift, a specified key, or a posted mouse move. Those need Accessibility, requested only when you choose them, never at launch. F15 is the usual pick (most keyboards lack it, so nothing is typed). Shift is invisible. A specified key or mouse move covers software that only watches those. A letter or number will type into the front app. It only steps in once you've been idle a few seconds, so it never types or nudges while you're using the Mac. Off by default."))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .animation(.snappy(duration: 0.25), value: model.simulateUserActivity)
        .animation(.snappy(duration: 0.25), value: model.activitySimulationMethod)
        .animation(.snappy(duration: 0.25), value: session.options.preventDisplaySleep)
        .onAppear { model.refreshAccessibilityTrust() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAccessibilityTrust()
        }
    }

    /// What the two switches add up to, in one plain sentence.
    private func sentence(sys: Bool, disp: Bool) -> String {
        switch (sys, disp) {
        case (true, true): L("The Mac keeps running and the screen stays lit: right for a dashboard or a video, and the fastest way to drain a battery.")
        case (true, false): L("The Mac keeps running, downloads finish, and it stays reachable, while the screen still turns off as usual. Most setups want this.")
        case (false, true): L("The screen stays lit, which also keeps the Mac running.")
        case (false, false): L("Neither is held, so a session does nothing. Turn one on.")
        }
    }

    private func methodDetail(_ method: ActivitySimulationMethod) -> String {
        switch method {
        case .powerWarp: L("Prompt-free. Some apps ignore this and need a key or mouse method.")
        case .f15: L("Posts F15 every 60 s. A common pick for software that watches the keyboard.")
        case .shift: L("Taps Shift every 60 s. Invisible, and nothing is typed.")
        case .specifiedKey: L("Taps the recorded key every 60 s. Prefer a function key or modifier.")
        case .mouseMove: L("Posts a 1-pixel mouse move every 60 s. For software that watches the pointer.")
        }
    }

    private func optionBinding(_ keyPath: WritableKeyPath<SleepPreventionOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { session.options[keyPath: keyPath] },
            set: { newValue in model.updateOptions { $0[keyPath: keyPath] = newValue } })
    }

    /// Turning dim-don't-sleep on picks a sensible delay and clears the
    /// screen-saver yield: after idle you either let the display sleep or dim
    /// it, not both.
    private var dimBinding: Binding<Bool> {
        Binding(
            get: { session.options.dimDisplayAfter != nil },
            set: { on in
                model.updateOptions {
                    $0.dimDisplayAfter = on ? Self.dimDefaultDelay : nil
                    if on { $0.allowScreenSaverAfter = nil }
                }
            })
    }
}

/// One activity method, as a radio row with its trade-off underneath.
private struct MethodRow: View {
    let title: String
    let detail: String
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(selected ? Color.panelAccentSolid : Color.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                    Text(verbatim: detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 34)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
