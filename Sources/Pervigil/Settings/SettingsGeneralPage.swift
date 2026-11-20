import SwiftUI
import AppKit
import PervigilCore

/// General: the app itself. Version and updates, startup, the global
/// shortcut, language, the helper at a glance, and the settings file.
struct SettingsGeneralPage: View {
    let updater: any Updating
    @Bindable var model: AppModel
    let navigate: (SettingsPage, String?) -> Void
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = LoginItem.isEnabled
    /// The result of the last export or import, shown under the buttons.
    @State private var transferNote: TransferNote?

    private struct TransferNote: Equatable { let message: String; let isError: Bool }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    MarkTile(size: 52, brand: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "Pervigil").font(.system(size: 15, weight: .semibold))
                        Text(verbatim: L("Version %@", AppInfo.version))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(updater.updateAvailable ? L("Update available…") : L("Check for Updates…")) {
                        updater.checkForUpdates()
                    }
                    .disabled(!updater.canCheckForUpdates)
                }
                .padding(.vertical, 4)
                .settingsAnchor("updates")
            } header: {
                PageHeader(page: .general, summary: L("Startup, the global shortcut, language, and your settings file."))
            }

            Section {
                ToggleRow(title: L("Launch at login"), symbol: "power", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        LoginItem.setEnabled(newValue)
                        launchAtLogin = LoginItem.isEnabled
                    }))
                    .settingsAnchor("login")
                ToggleRow(
                    title: L("Start keep-awake on launch"),
                    subtitle: model.triggersEnabled
                        ? L("Ignored while triggers are on: your conditions decide.")
                        : L("Starts a session as soon as Pervigil launches."),
                    symbol: "play",
                    isOn: Binding(get: { model.startOnLaunch }, set: { model.startOnLaunch = $0 }))
                    .settingsAnchor("startOnLaunch")
            } header: {
                GroupHeader(L("Startup"), info: L("\u{201C}Launch at login\u{201D} starts Pervigil itself when you log in, so the icon is always in the menu bar. \u{201C}Start keep-awake on launch\u{201D} goes further and begins a session right away, using the default duration, for an always-on Mac that shouldn't need a rule to stay up. It's ignored while triggers are controlling activation, since your conditions decide then."))
            }

            Section {
                LabeledContent {
                    ShortcutRecorder(shortcut: Binding(get: { model.hotKey }, set: { model.hotKey = $0 }))
                } label: {
                    RowLabel(title: L("Toggle shortcut"), subtitle: L("Starts or stops keep-awake from any app."), symbol: "keyboard")
                }
                .settingsAnchor("shortcut")
            } header: {
                GroupHeader(L("Global shortcut"), info: L("System-wide, so it starts or stops keep-awake whatever app you're in. It needs at least one modifier key (Command, Option, Control, or Shift) so it can't fire while you're typing. Recording it asks for no Accessibility or Input Monitoring permission."))
            }

            Section {
                Picker(selection: Binding(get: { AppLanguage.current }, set: { switchLanguage(to: $0) })) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.label).tag(language)
                    }
                } label: {
                    RowLabel(title: L("App language"), subtitle: L("Pervigil follows your system language by default."), symbol: "globe")
                }
                .settingsAnchor("language")
            } header: {
                GroupHeader(L("Language"), info: L("Fifteen languages are available. Changing this relaunches Pervigil, so the menu, every window, and notifications all switch together instead of drifting apart. Set it back to \u{201C}Follow System\u{201D} to follow your Mac's language again."))
            }

            Section {
                Button { navigate(.helper, nil) } label: {
                    LabeledContent {
                        HStack(spacing: 6) {
                            StatusPill(text: helperStateLabel, tint: helperTint)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                    } label: {
                        RowLabel(
                            title: L("Administrator helper"),
                            subtitle: L("Handles the privileged switches for Pervigil, with no password prompts."),
                            symbol: "lock.shield",
                            tint: helperTint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .settingsAnchor("helper")
            }

            Section {
                LabeledContent {
                    HStack {
                        Button(L("Import Settings\u{2026}")) { importSettings() }
                        Button(L("Export Settings\u{2026}")) { exportSettings() }
                    }
                } label: {
                    RowLabel(title: L("Backup"), subtitle: L("Save your settings, triggers, and presets to a JSON file."), symbol: "doc")
                }
                .settingsAnchor("backup")
                if let note = transferNote {
                    RowNote(text: note.message, kind: note.isError ? .warning : .success)
                }
            } header: {
                GroupHeader(L("Settings file"), info: L("Writes everything you've configured (settings, trigger rules, and presets) to a JSON file, to keep as a backup or to carry to another Mac. The file is version-stamped and checked on import, so a file from a newer Pervigil is refused rather than half-read. Importing replaces your current configuration and ends any running session."))
            }

            Section {
                LabeledContent {
                    Button(L("Show Welcome Screen\u{2026}")) {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: PervigilApp.welcomeWindowID)
                    }
                } label: {
                    RowLabel(title: L("Welcome"), subtitle: L("Reopen the first-run welcome, with quick one-click setup for how you use your Mac."), symbol: "hand.wave")
                }
                .settingsAnchor("welcome")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .animation(.snappy(duration: 0.25), value: transferNote)
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }

    private var helperStateLabel: String {
        if model.helperInstalled && !model.helper.daemonOutdated { return L("Ready") }
        if model.helper.awaitingApproval { return L("Needs approval") }
        if model.helper.daemonOutdated { return L("Updating") }
        return L("Not installed")
    }

    private var helperTint: SettingsTint {
        if model.helperInstalled && !model.helper.daemonOutdated { return .met }
        if model.helper.awaitingApproval || model.helper.daemonOutdated { return .warning }
        return .neutral
    }

    /// Persist a new language choice and relaunch so every surface switches
    /// at once (the `AppleLanguages` override only resolves at process start).
    private func switchLanguage(to language: AppLanguage) {
        guard language != AppLanguage.current else { return }
        language.apply()
        AppLanguage.relaunch()
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.title = L("Export Pervigil Settings")
        panel.nameFieldStringValue = "Pervigil Settings.json"
        panel.allowedContentTypes = [.json]
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.exportSettingsData().write(to: url)
            transferNote = TransferNote(message: L("Exported to %@.", url.lastPathComponent), isError: false)
        } catch {
            transferNote = TransferNote(message: L("Couldn't export settings: %@", error.localizedDescription), isError: true)
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.title = L("Import Pervigil Settings")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let disabledShellHooks = try model.importSettings(from: Data(contentsOf: url))
            let message = disabledShellHooks > 0
                ? L("Settings imported. %d command hook(s) were disabled for safety. Review them in Automation before turning them on.", disabledShellHooks)
                : L("Settings imported.")
            transferNote = TransferNote(message: message, isError: false)
        } catch let error as SettingsTransferError {
            switch error {
            case .unrecognizedFile:
                transferNote = TransferNote(message: L("That file isn't a Pervigil settings export."), isError: true)
            case .unsupportedVersion:
                transferNote = TransferNote(message: L("That export was made by a newer version of Pervigil."), isError: true)
            }
        } catch {
            transferNote = TransferNote(message: L("Couldn't read the file: %@", error.localizedDescription), isError: true)
        }
    }
}
