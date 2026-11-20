import SwiftUI
import PervigilCore

/// Triggers: the conditions Pervigil checks once a second, with their live
/// state, and presets to swap whole sets of them.
struct SettingsTriggersPage: View {
    @Bindable var model: AppModel
    let navigate: (SettingsPage, String?) -> Void
    @State private var newPresetName = ""
    @State private var appliedPreset: String?

    var body: some View {
        Form {
            if model.triggersEnabled {
                Section {
                    RulesView(model: model)
                } header: {
                    GroupHeader(title: nil) {
                        pageHeader
                        if model.triggersPaused {
                            HStack(spacing: 8) {
                                RowNote(text: L("Set to Manual in the menu bar."), kind: .warning, indented: false)
                                Spacer()
                                Button(L("Switch to Automatic")) { model.resumeTriggers() }
                            }
                            .padding(.bottom, 12)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            RulesView.combineHeader(model: model)
                            Spacer()
                            summaryPill
                        }
                    }
                    .settingsAnchor("rules")
                } footer: {
                    // Heat isn't a condition: a "too hot" rule that merely stops
                    // satisfying could be outvoted by any other rule in "any"
                    // mode. Point people who come looking to the real thing.
                    // Laptops only: a desktop has no lid, so no heat guard.
                    if model.machineHasBattery {
                        HStack(spacing: 4) {
                            Text(verbatim: L("Looking for heat? \u{201C}Pause when running hot\u{201D} is under %@.", SettingsPage.power.title))
                            Button(L("Show")) { navigate(.power, "heat") }.buttonStyle(.link)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
                    PresetChips(model: model) { name in
                        appliedPreset = name
                    }
                    .settingsAnchor("presets")
                    if let appliedPreset {
                        RowNote(text: L("Applied \u{201C}%@\u{201D}. Your rules were replaced.", appliedPreset), kind: .success, indented: false)
                    }
                    HStack(spacing: 6) {
                        TextField(L("Save current rules as\u{2026}"), text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(savePreset)
                        Button(L("Save")) { savePreset() }
                            .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty || model.rules.isEmpty)
                    }
                } header: {
                    HStack(spacing: 4) {
                        Text(verbatim: L("Presets"))
                        InfoButton(text: L("A preset is a named bundle of trigger rules you apply in one click. The built-ins cover common setups (AI Agent, Meetings, Cloud Gaming, Remote Control, and more), and applying one replaces your current rules. Save your own rules under a name to reuse them or move between setups. Renaming a built-in makes it yours, and Pervigil stops updating it. \u{201C}Restore default presets\u{201D} brings back any built-in you removed."))
                        Spacer()
                        manageMenu
                    }
                    .textCase(nil)
                }
            } else {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "checklist").font(.system(size: 26, weight: .light)).foregroundStyle(.secondary)
                        Text(verbatim: L("Triggers are off. The Mac stays awake only when you start a session from the menu."))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button(L("Turn On Triggers")) { model.triggersEnabled = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                } header: {
                    pageHeader
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        // Hook rows refresh their own tool's state on appear, but a row whose
        // tool is undetected renders nothing, so read here, from a view that
        // always exists (see the old Triggers tab for the full story).
        .onAppear { model.refreshAgentHookStatuses() }
        .animation(.snappy(duration: 0.25), value: model.triggersEnabled)
        .animation(.snappy(duration: 0.25), value: model.triggersPaused)
        .animation(.snappy(duration: 0.25), value: appliedPreset)
    }

    private var pageHeader: some View {
        PageHeader(page: .triggers, summary: L("Conditions Pervigil checks once a second. While they hold, the Mac stays awake. When they stop, it can sleep.")) {
            Toggle("", isOn: Binding(get: { model.triggersEnabled }, set: { model.triggersEnabled = $0 }))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(L("Activate by triggers"))
                .help(L("The listed conditions control the session instead of the manual switch."))
        }
    }

    @ViewBuilder
    private var summaryPill: some View {
        let states = model.ruleStates() ?? []
        if !states.isEmpty {
            let met = states.filter { $0.satisfied || $0.inGrace }.count
            let awake = model.session.isActive && !model.triggersPaused
            StatusPill(
                text: L("%d of %d met", met, states.count) + " · " + (awake ? L("Awake") : L("Can sleep")),
                tint: awake ? .met : .neutral)
        }
    }

    private var manageMenu: some View {
        Menu {
            ForEach(model.presets) { preset in
                Button(L("Remove \u{201C}%@\u{201D}", preset.displayName), role: .destructive) {
                    model.removePreset(preset)
                }
            }
            if !model.missingBuiltInPresets.isEmpty {
                Divider()
                Button(L("Restore default presets")) { model.restoreDefaultPresets() }
            }
        } label: {
            Text(verbatim: L("Manage"))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(model.presets.isEmpty && model.missingBuiltInPresets.isEmpty)
    }

    private func savePreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !model.rules.isEmpty else { return }
        model.saveCurrentRulesAsPreset(named: name)
        newPresetName = ""
    }
}

/// Every preset as a one-click chip. Applying replaces the current rules.
private struct PresetChips: View {
    @Bindable var model: AppModel
    let applied: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(model.presets) { preset in
                Button {
                    model.applyPreset(preset)
                    applied(preset.displayName)
                } label: {
                    Text(verbatim: preset.displayName)
                        .font(.system(size: 12.5))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 26)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle(scale: 0.96))
            }
        }
        .padding(.vertical, 2)
    }
}

/// Lays children out in rows, wrapping when a row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width && !row.indices.isEmpty {
                let y = row.y + row.height + spacing
                rows.append(Row(indices: [index], y: y, width: size.width, height: size.height))
                continue
            }
            row.indices.append(index)
            row.width = needed
            row.height = max(row.height, size.height)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
