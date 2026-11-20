import SwiftUI
import PervigilCore

/// Devices: keep external drives ready, and give a Mac with no monitor a
/// sharper remote picture.
struct SettingsDevicesPage: View {
    @Bindable var model: AppModel

    private static let intervals: [TimeInterval] = [60, 5 * 60, 10 * 60, 30 * 60]
    private static let resolutions: [(width: Int, height: Int, name: String)] = [
        (1920, 1080, "Full HD"), (2560, 1440, "QHD"), (2880, 1620, "3K"), (3840, 2160, "4K"),
    ]
    private static let defaultDisplay = VirtualDisplayConfig(width: 2560, height: 1440, hiDPI: true)

    var body: some View {
        Form {
            Section {
                ToggleRow(
                    title: L("Keep a disk spinning"),
                    subtitle: L("Stops an external drive or NAS from spinning down."),
                    symbol: "externaldrive",
                    isOn: Binding(get: { model.diskKeepAliveEnabled }, set: { on in
                        on ? model.chooseDiskFolder() : model.disableDiskKeepAlive()
                    }))
                    .settingsAnchor("disk")
                if model.diskKeepAliveEnabled {
                    LabeledContent {
                        HStack(spacing: 6) {
                            Label(model.diskKeepAliveDirectory?.lastPathComponent ?? L("None"), systemImage: "folder")
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Button(L("Change…")) { model.chooseDiskFolder() }.buttonStyle(.link)
                        }
                    } label: {
                        RowLabel(title: L("Folder"), indented: true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: L("Touch"))
                        ChipPicker(
                            options: Self.intervals.map { ($0, SettingsFormat.short($0)) },
                            selection: Binding(get: { model.diskKeepAliveInterval }, set: { model.diskKeepAliveInterval = $0 }),
                            columns: 4)
                    }
                    .padding(.leading, 34)
                }
            } header: {
                GroupHeader(title: L("Disk"), info: L("Many external drives and NAS volumes park or disconnect after a few minutes idle, and the next thing that touches them stalls while they spin back up. Pervigil rewrites a tiny hidden marker file in the folder you choose, just enough activity to keep the volume awake. Pick an interval shorter than the drive's own idle timeout. This runs whenever Pervigil is running, with or without a keep-awake session, so a drive stays ready even when the Mac is free to sleep.")) {
                    PageHeader(page: .devices, summary: L("Keep external drives ready, and give a Mac with no monitor a sharper remote picture."))
                }
            }

            Section {
                ToggleRow(
                    title: L("Create a virtual display"),
                    subtitle: model.virtualDisplaySupported
                        ? L("For a Mac with no monitor: a sharper picture over Screen Sharing and VNC.")
                        : L("Not available on this macOS version."),
                    symbol: "display",
                    isOn: Binding(get: { model.virtualDisplayEnabled }, set: { on in
                        model.setVirtualDisplay(on ? Self.defaultDisplay : nil)
                    }))
                    .disabled(!model.virtualDisplaySupported)
                    .settingsAnchor("virtualDisplay")
                if let config = model.virtualDisplayConfig {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(Self.resolutions, id: \.width) { resolution in
                            PictureChoice(
                                value: resolution.width,
                                selection: Binding(get: { config.width }, set: { width in
                                    guard let r = Self.resolutions.first(where: { $0.width == width }) else { return }
                                    model.setVirtualDisplay(VirtualDisplayConfig(width: r.width, height: r.height, hiDPI: config.hiDPI))
                                }),
                                title: "\(resolution.width) \u{00D7} \(resolution.height)",
                                detail: resolution.name,
                                centered: true
                            ) {
                                let scale = CGFloat(resolution.width) / 1920
                                RoundedRectangle(cornerRadius: 2).strokeBorder(lineWidth: 1.4)
                                    .frame(width: 24 * scale, height: 14 * scale)
                            }
                        }
                    }
                    .padding(.leading, 34)
                    ToggleRow(title: L("HiDPI (Retina)"), indented: true, isOn: Binding(
                        get: { config.hiDPI },
                        set: { model.setVirtualDisplay(VirtualDisplayConfig(width: config.width, height: config.height, hiDPI: $0)) }))
                    if let error = model.virtualDisplayError {
                        RowNote(text: error, kind: .warning)
                    }
                }
            } header: {
                HStack(spacing: 6) {
                    Text(verbatim: L("Headless display"))
                    StatusPill(text: L("Experimental"))
                    InfoButton(text: L("A Mac with no monitor attached falls back to a fuzzy 1920 \u{00D7} 1080, which is what makes Screen Sharing and VNC look soft. This creates a higher-resolution HiDPI display in software, so the remote picture is crisp without plugging anything in. It uses a private macOS API, so treat it as experimental and expect it may break on a macOS update. A hardware HDMI or DisplayPort dummy plug does the same job with no software at all."))
                }
                .textCase(nil)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .animation(.snappy(duration: 0.25), value: model.diskKeepAliveEnabled)
        .animation(.snappy(duration: 0.25), value: model.virtualDisplayEnabled)
    }
}
