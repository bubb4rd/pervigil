import SwiftUI
import PervigilCore

/// Automatic or Manual, and the duration chips. The switch always shows, so a
/// new user can find Automatic: choosing it turns triggers on. In Automatic the trigger
/// section below does the explaining; in Manual the chips start a session in
/// one click, and re-time a running one.
struct PanelSessionSection: View {
    @Bindable var model: AppModel

    private enum ControlMode: Hashable { case automatic, manual }
    private enum Editor { case until, custom }

    @State private var editor: Editor?
    @State private var untilTime = Date().addingTimeInterval(60 * 60)
    @State private var customMinutes = 90

    private var session: SessionController { model.session }
    private var triggersControlling: Bool { model.triggersEnabled && !model.triggersPaused }

    var body: some View {
        VStack(alignment: .leading, spacing: PanelTokens.sectionGap) {
            Picker(L("Keep awake mode"), selection: Binding(
                get: { triggersControlling ? ControlMode.automatic : .manual },
                set: { mode in
                    switch mode {
                    case .automatic:
                        if !model.triggersEnabled { model.triggersEnabled = true }
                        model.resumeTriggers()
                    case .manual:
                        if model.triggersEnabled { model.pauseTriggers() }
                    }
                }
            )) {
                Text("Automatic").tag(ControlMode.automatic)
                Text("Manual").tag(ControlMode.manual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if !triggersControlling {
                chips
            }
        }
    }

    private var manualSessionRunning: Bool { session.isActive && !model.heldByAutomation }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(manualSessionRunning ? L("Change to") : L("Keep awake for"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    chip(L("No limit"), selected: isSelected(.noLimit)) { start(.indefinite, .noLimit) }
                    chip(MenuBarContent.shortDuration(15 * 60), selected: isSelected(.minutes(15))) {
                        start(.timed(duration: 15 * 60), .minutes(15))
                    }
                    chip(MenuBarContent.shortDuration(60 * 60), selected: isSelected(.minutes(60))) {
                        start(.timed(duration: 60 * 60), .minutes(60))
                    }
                }
                GridRow {
                    chip(MenuBarContent.shortDuration(4 * 60 * 60), selected: isSelected(.minutes(240))) {
                        start(.timed(duration: 4 * 60 * 60), .minutes(240))
                    }
                    chip(L("Until…"), selected: editor == .until || isSelected(.until)) { toggle(.until) }
                    chip(L("Custom…"), selected: editor == .custom || isSelected(.custom)) { toggle(.custom) }
                }
            }
            if let editor {
                inlineEditor(editor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Text("Manual sets your triggers aside without changing them.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
        .animation(.snappy(duration: 0.25), value: editor)
    }

    private func isSelected(_ choice: PanelDurationChoice) -> Bool {
        guard manualSessionRunning else { return false }
        return (model.panelDurationChoice ?? AppModel.choice(for: session.mode)) == choice
    }

    private func start(_ mode: SessionMode, _ choice: PanelDurationChoice) {
        editor = nil
        model.startPanelSession(mode, choice: choice)
    }

    private func toggle(_ next: Editor) {
        editor = editor == next ? nil : next
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.panelAccentSolid : Color.primary.opacity(0.06)))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.96))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func inlineEditor(_ editor: Editor) -> some View {
        let verb = manualSessionRunning ? L("Update") : L("Start")
        HStack(spacing: 8) {
            switch editor {
            case .until:
                Text("Until")
                DatePicker("Until", selection: $untilTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)
                Spacer(minLength: 4)
                Button(verb) {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: untilTime)
                    self.editor = nil
                    model.startPanelSession(untilHour: parts.hour ?? 0, minute: parts.minute ?? 0)
                }
                .buttonStyle(KeepAwakeButtonStyle())
            case .custom:
                Text("For")
                TextField("Minutes", value: $customMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .monospacedDigit()
                Text("minutes")
                Spacer(minLength: 4)
                Button(verb) {
                    let minutes = min(max(customMinutes, 1), Int(SessionMode.maxTimedMinutes))
                    self.editor = nil
                    model.startPanelSession(.timed(duration: TimeInterval(minutes * 60)), choice: .custom)
                }
                .buttonStyle(KeepAwakeButtonStyle())
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 2)
        if editor == .until {
            Text("If that time already passed today, it means tomorrow.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 2)
        }
    }
}
