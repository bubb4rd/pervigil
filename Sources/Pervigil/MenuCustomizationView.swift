import SwiftUI
import PervigilCore

extension PanelSection {
    var label: String {
        switch self {
        case .status: L("Status")
        case .session: L("Session controls")
        case .triggers: L("Triggers")
        case .guards: L("Quick settings")
        case .footer: L("App shortcuts")
        }
    }
}

extension MenuBarTextStyle {
    var label: String {
        switch self {
        case .existing: L("Follow countdown setting")
        case .iconOnly: L("Icon only")
        case .remaining: L("Remaining time")
        case .elapsed: L("Elapsed time")
        case .endTime: L("End time")
        case .status: L("Status")
        }
    }
}

/// Customize Menu: show, hide, and reorder the panel's sections, and choose
/// what the menu bar shows. Presentation only; feature settings never change
/// here, and the standard menu is one switch away.
struct MenuCustomizationView: View {
    @Bindable var model: AppModel
    @State private var previewExpanded = true
    @State private var previewBridge = StatusItemBridge(updater: MenuPreviewUpdater())
    @State private var windowVisible = false
    private var layout: MenuLayout { model.editableMenuLayout }

    private func binding<T>(_ keyPath: WritableKeyPath<MenuLayout, T>) -> Binding<T> {
        Binding(get: { layout[keyPath: keyPath] }, set: { value in
            model.updateMenuLayout { $0[keyPath: keyPath] = value }
        })
    }

    var body: some View {
        Group {
            if windowVisible { editor }
            else { Color.clear }
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 560, idealHeight: 720)
        .glassWindowBackground()
        .background(WindowVisibilityReader(isVisible: $windowVisible))
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Customize menu sections", isOn: Binding(
                    get: { model.menuCustomizationEnabled }, set: { model.menuCustomizationEnabled = $0 }
                ))
                .toggleStyle(.switch).controlSize(.small)
                Spacer()
                Button("Use standard menu") { model.menuCustomizationEnabled = false }
                    .disabled(!model.menuCustomizationEnabled)
            }
            .padding(20)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    sectionsEditor
                    HStack {
                        Button("Reset customization") { model.updateMenuLayout { $0 = MenuLayout() } }
                            .disabled(!model.menuCustomizationEnabled)
                        Spacer()
                        InfoButton(text: L("Warnings stay visible. Preferences and Quit are also available by right-clicking the icon."))
                    }
                    .padding(20)
                }
                .frame(minWidth: 340, maxWidth: 400)
                Divider()
                previewPane
            }
        }
        .tint(.pervigilAccent)
    }

    private var sectionsEditor: some View {
        Form {
            if !model.menuCustomizationEnabled {
                Section { Text("Enable customization to edit the menu.").foregroundStyle(.secondary) }
            } else {
                Section {
                    ForEach(layout.panel.order) { section in sectionRow(section) }
                } header: {
                    Text("Sections")
                } footer: {
                    Text("Show, hide, or reorder whole sections. The status card always stays on top.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Picker("Menu bar", selection: binding(\.menuBarTextStyle)) {
                        ForEach(MenuBarTextStyle.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Show menu-bar icon", isOn: binding(\.showMenuBarIcon))
                        .disabled([.existing, .iconOnly].contains(layout.menuBarTextStyle))
                } header: { Text("Menu bar") }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func sectionRow(_ section: PanelSection) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { layout.panel.isVisible(section) },
                set: { visible in model.updateMenuLayout { $0.panel.setVisible(section, visible) } }
            )) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.label)
                    if section.isPinned {
                        Text("Always shown").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(section.isPinned)
            .frame(maxWidth: .infinity, alignment: .leading)
            moveButton(up: true, label: section.label, disabled: !layout.panel.canMove(section, by: -1)) {
                model.updateMenuLayout { $0.panel.move(section, by: -1) }
            }
            moveButton(up: false, label: section.label, disabled: !layout.panel.canMove(section, by: 1)) {
                model.updateMenuLayout { $0.panel.move(section, by: 1) }
            }
        }
        .controlSize(.small)
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Preview").font(.headline)
                Spacer()
                Label("Live", systemImage: "circle.fill").font(.caption).foregroundStyle(.secondary)
            }
            Picker("Preview", selection: $previewExpanded) {
                Text("Full panel").tag(true)
                Text("Compact strip").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            ScrollView([.vertical]) {
                VStack(spacing: 16) {
                    MenuBarLabel(session: model.session, showCountdown: model.showCountdownInMenuBar,
                                 presentation: model.advancedMenuLayout, automation: model.heldByAutomation)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())
                        .allowsHitTesting(false)
                    MenuBarContent(model: model, updater: MenuPreviewUpdater(), bridge: previewBridge,
                                   preview: MenuPreviewConfiguration(
                                    layout: model.advancedMenuLayout, expanded: previewExpanded))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            Text("Preview only. Controls do not change your session.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.quaternary.opacity(0.35))
        .onAppear { previewExpanded = model.menuPanelExpanded }
    }

    private func moveButton(up: Bool, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: up ? "chevron.up" : "chevron.down") }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(L(up ? "Move up" : "Move down")): \(label)")
            .disabled(disabled)
    }
}

private struct MenuPreviewUpdater: Updating {
    var canCheckForUpdates: Bool { true }
    func checkForUpdates() {}
}
