import SwiftUI
import AppKit
import PervigilCore

/// Preferences, the switch to the compact strip, and everything else in one
/// More menu (tools, presets, Customize Menu, help, Quit).
struct PanelFooter: View {
    @Bindable var model: AppModel
    let updater: any Updating
    let open: (String) -> Void
    let enabled: Bool

    var body: some View {
        VStack(spacing: 6) {
            Divider()
            HStack(spacing: 2) {
                Button {
                    open(PervigilApp.preferencesWindowID)
                } label: {
                    HStack {
                        Text("Preferences…")
                        Spacer()
                        Text(verbatim: "⌘,").foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.menuRow)
                .keyboardShortcut(enabled ? KeyboardShortcut(",", modifiers: .command) : nil)

                iconButton("rectangle.compress.vertical", label: L("Compact panel")) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { model.menuPanelExpanded = false }
                }

                Menu {
                    Button("Headless Setup…") { open(PervigilApp.setupWindowID) }
                    Button("Gaming & Streaming…") { open(PervigilApp.streamingWindowID) }
                    Button("Keyboard Cleaner…") { open(PervigilApp.keyboardCleanerWindowID) }
                    Button("Public Wi-Fi…") { open(PervigilApp.wifiAssistantWindowID) }
                    if !model.presets.isEmpty {
                        Divider()
                        Menu("Presets") {
                            ForEach(model.presets) { preset in
                                Button(preset.displayName) { model.applyPreset(preset) }
                            }
                        }
                    }
                    Divider()
                    Button("Customize Menu…") { open(PervigilApp.menuCustomizationWindowID) }
                    Button("Welcome to Pervigil…") { open(PervigilApp.welcomeWindowID) }
                    Button("About Pervigil") { open(PervigilApp.aboutWindowID) }
                    Button("Check for Updates…") { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                    Button("Support Pervigil…") { NSWorkspace.shared.open(AppInfo.donate) }
                    Divider()
                    Button("Quit Pervigil") { NSApplication.shared.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(width: 26, height: 26)
                .help(L("More"))
                .accessibilityLabel(L("More"))
            }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13)).frame(width: 26, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(label)
        .accessibilityLabel(label)
    }
}
