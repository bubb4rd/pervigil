import SwiftUI
import PervigilCore

/// Administrator Helper: one approval, then the privileged switches work
/// without password prompts. Says what state the helper is in and exactly
/// what it unlocks, with a link to each feature.
struct SettingsHelperPage: View {
    @Bindable var model: AppModel
    let navigate: (SettingsPage, String?) -> Void

    private enum HelperState { case ready, approval, missing }

    private var state: HelperState {
        switch model.helper.status {
        case .enabled: .ready
        case .requiresApproval: .approval
        default: .missing
        }
    }

    /// Without the helper, a feature either asks for a password, is not
    /// available at all, or falls back to System Events.
    private enum Without { case password, unavailable, systemEvents }

    private struct Feature {
        let title: String
        let symbol: String
        let without: Without
        let link: (SettingsPage, String)?
    }

    private var features: [Feature] {
        [
            Feature(title: L("Closed-display mode"), symbol: "laptopcomputer", without: .password, link: (.power, "lidMode")),
            Feature(title: L("Low Power Mode while the lid is closed"), symbol: "leaf", without: .unavailable, link: (.power, "lowPower")),
            Feature(title: L("Fan boost and minimum fan speed"), symbol: "fan", without: .unavailable, link: (.power, "heat")),
            Feature(title: L("Scheduled wake"), symbol: "alarm", without: .unavailable, link: (.automation, "wake")),
            Feature(title: L("Scheduled AI runs"), symbol: "calendar", without: .unavailable, link: (.automation, "sync")),
            Feature(title: L("Sleep the Mac"), symbol: "moon.zzz", without: .systemEvents, link: (.automation, "endAction")),
            Feature(title: L("AWDL pausing in Gaming & Streaming"), symbol: "wifi", without: .password, link: nil),
            Feature(title: L("Keyboard Cleaner"), symbol: "keyboard", without: .password, link: nil),
            Feature(title: L("DNS flush in Public Wi-Fi"), symbol: "globe", without: .password, link: nil),
        ]
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: heroSymbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(heroTint.ink)
                        .frame(width: 46, height: 46)
                        .background(heroTint.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: heroTitle).font(.system(size: 15, weight: .semibold))
                        Text(verbatim: heroDetail).font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    heroAction
                }
                .padding(.vertical, 4)
                .settingsAnchor("status")
                if state == .approval {
                    VStack(alignment: .leading, spacing: 6) {
                        step(1, L("Pervigil registered the helper"), done: true)
                        step(2, L("Open System Settings ▸ General ▸ Login Items & Extensions"), done: false)
                        step(3, L("Under \u{201C}Allow in the Background\u{201D}, turn on Pervigil and enter your password once"), done: false)
                    }
                    .padding(.leading, 60)
                }
                if let hint = model.helperRecoveryHint {
                    RowNote(text: hint, indented: false)
                }
                if let error = model.helper.lastError {
                    HelperFeatureNotice(model: model, message: error, helperOnly: true).font(.caption)
                }
            } header: {
                PageHeader(page: .helper, summary: L("One approval, then the privileged switches work without password prompts."))
            }

            Section {
                ForEach(features, id: \.title) { feature in
                    LabeledContent {
                        HStack(spacing: 6) {
                            if state == .ready {
                                Image(systemName: "checkmark").font(.callout.weight(.semibold)).foregroundStyle(Color.panelGreenText)
                                    .accessibilityLabel(L("Ready"))
                            } else {
                                Text(verbatim: withoutText(feature.without)).font(.caption).foregroundStyle(.secondary)
                            }
                            if let link = feature.link {
                                Button { navigate(link.0, link.1) } label: {
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.tertiary)
                                .accessibilityLabel(L("Show %@", feature.title))
                            }
                        }
                    } label: {
                        RowLabel(title: feature.title, symbol: feature.symbol, tint: state == .ready ? .met : .neutral)
                    }
                }
            } header: {
                GroupHeader(state == .ready ? L("What it handles") : L("What it unlocks"))
                    .settingsAnchor("features")
            } footer: {
                sectionFooter("It can only flip these specific switches. Everything it changes is restored if Pervigil quits or crashes, and you can remove it here at any time.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear { model.helper.refresh() }
    }

    private var heroSymbol: String {
        switch state {
        case .ready: "checkmark.shield"
        case .approval: "hourglass"
        case .missing: "lock.shield"
        }
    }

    private var heroTint: SettingsTint {
        switch state {
        case .ready: .met
        case .approval: .warning
        case .missing: .neutral
        }
    }

    private var heroTitle: String {
        switch state {
        case .ready: L("Installed and ready")
        case .approval: L("Waiting for your approval")
        case .missing: L("Not installed")
        }
    }

    private var heroDetail: String {
        switch state {
        case .ready: L("Privileged switches work instantly, with no password prompts. It updates itself with the app.")
        case .approval: L("One step left, in System Settings. This page updates on its own when you are done.")
        case .missing: L("A small system service for the switches that need administrator rights. Without it, macOS asks for your password once per app run, and fan control stays off.")
        }
    }

    @ViewBuilder
    private var heroAction: some View {
        switch state {
        case .ready:
            Button(L("Remove")) { model.removeHelper() }.disabled(model.helperOperationInFlight)
        case .approval:
            Button(L("Open Login Items")) { model.helper.openApprovalSettings() }.buttonStyle(.borderedProminent)
        case .missing:
            Button(L("Install Helper…")) { model.installHelper() }
                .buttonStyle(.borderedProminent)
                .disabled(model.helperOperationInFlight)
        }
    }

    private func withoutText(_ without: Without) -> String {
        switch without {
        case .password: L("Asks for your password")
        case .unavailable: L("Unavailable")
        case .systemEvents: L("Uses System Events")
        }
    }

    private func step(_ number: Int, _ text: String, done: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Group {
                if done {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.panelGreenText)
                } else {
                    Text(verbatim: "\(number)").font(.system(size: 10.5, weight: .semibold))
                }
            }
            .frame(width: 18, height: 18)
            .background(done ? Color.panelGreenText.opacity(0.15) : Color.primary.opacity(0.08), in: Circle())
            Text(verbatim: text).font(.callout).foregroundStyle(.secondary)
        }
    }
}
