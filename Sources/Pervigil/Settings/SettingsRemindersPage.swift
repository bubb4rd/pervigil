import SwiftUI
import PervigilCore

/// Reminders: a nudge while a session runs, and a heads-up when it ends on
/// its own. Opens with a timeline of one timed session that shows when each
/// notification fires, and previews the exact notification.
struct SettingsRemindersPage: View {
    @Bindable var model: AppModel
    let navigate: (SettingsPage, String?) -> Void
    /// The session length the timeline is drawn for.
    @State private var previewLength: TimeInterval = 4 * 3600
    /// The notification shown under the timeline.
    @State private var previewKind: ReminderTimeline.Kind = .reminder

    private static let intervals: [TimeInterval] = [15 * 60, 30 * 60, 3600, 2 * 3600, 4 * 3600, 8 * 3600]
    private static let notices: [TimeInterval] = [60, 2 * 60, 5 * 60, 10 * 60]

    var body: some View {
        let timeline = ReminderTimeline.make(
            length: previewLength,
            reminderEnabled: model.reminderEnabled,
            reminderAfter: model.reminderAfter,
            reminderRepeats: model.reminderRepeats,
            endingSoonEnabled: model.endingSoonEnabled,
            endingSoonNotice: model.endingSoonNotice,
            notifyOnEnd: model.notifyOnEnd)
        Form {
            Section {
                TimelinePreview(
                    timeline: timeline,
                    length: $previewLength,
                    selected: $previewKind,
                    banner: banner(for: previewKind, in: timeline),
                    legend: legend)
                    .settingsAnchor("timeline")
            } header: {
                PageHeader(page: .reminders, summary: L("A nudge while a session runs, and a heads-up when it ends on its own. Nothing here ever stops a session."))
            }

            Section {
                ToggleRow(
                    title: L("Remind me it's still on"),
                    subtitle: model.reminderEnabled
                        ? (model.reminderRepeats
                            ? L("A recurring notification every interval while a session runs, so a Mac left awake keeps reminding you.")
                            : L("A one-time notification once a session has run this long, in case you forget the Mac is awake."))
                        : nil,
                    symbol: "bell",
                    isOn: Binding(get: { model.reminderEnabled }, set: { model.reminderEnabled = $0 }))
                    .settingsAnchor("reminder")
                if model.reminderEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: model.reminderRepeats ? L("Every") : L("After"))
                        ChipPicker(
                            options: Self.intervals.map { ($0, SettingsFormat.short($0)) },
                            selection: Binding(get: { model.reminderAfter }, set: { model.reminderAfter = $0 }),
                            columns: 6)
                    }
                    .padding(.leading, 34)
                    ToggleRow(title: L("Repeat the reminder"), indented: true,
                              isOn: Binding(get: { model.reminderRepeats }, set: { model.reminderRepeats = $0 }))
                    ToggleRow(title: L("Play a sound"), indented: true,
                              isOn: Binding(get: { model.reminderSound }, set: { model.reminderSound = $0 }))
                }
            } header: {
                GroupHeader(L("While a session runs"), info: L("A nudge while a session is running, so a Mac left awake doesn't stay awake all night unnoticed. Left off, a one-time reminder tells you once, after the session has run this long. \u{201C}Repeat\u{201D} tells you again at every interval until you stop the session. This never stops anything itself, it only reminds you, and the sound is optional. If you'd rather the session end on its own, use a timed session or a quick-stop button instead."))
            }

            Section {
                ToggleRow(
                    title: L("Notify when a session ends"),
                    subtitle: L("A timer runs out, or the triggers stop holding."),
                    symbol: "stop.circle",
                    isOn: Binding(get: { model.notifyOnEnd }, set: { model.notifyOnEnd = $0 }))
                    .settingsAnchor("notifyEnd")
                ToggleRow(
                    title: L("Warn before a timed session ends"),
                    subtitle: L("Time to extend it from the menu before the Mac drops off."),
                    symbol: "clock",
                    onTint: .warning,
                    isOn: Binding(get: { model.endingSoonEnabled }, set: { model.endingSoonEnabled = $0 }))
                    .settingsAnchor("endingSoon")
                if model.endingSoonEnabled {
                    ChipPicker(
                        options: noticeChoices.map { ($0, L("%@ before", SettingsFormat.short($0))) },
                        selection: Binding(get: { model.endingSoonNotice }, set: { model.endingSoonNotice = $0 }),
                        columns: noticeChoices.count)
                        .padding(.leading, 34)
                }
            } header: {
                GroupHeader(L("When a session ends on its own"), info: L("These cover the times a session ends without you: a timer expiring, or trigger conditions dropping. Stopping it yourself stays silent, since you already know. The warning is a heads-up a few minutes before a timed session runs out, so you can extend it before the Mac drops off. Actions that put the Mac to sleep live under Automation."))
            } footer: {
                HStack(spacing: 4) {
                    Text(verbatim: L("Notifications fire when a session ends on its own, not when you stop it yourself."))
                    Button(L("Sleep or lock the Mac instead…")) { navigate(.automation, "endAction") }
                        .buttonStyle(.link)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .animation(.snappy(duration: 0.25), value: model.reminderEnabled)
        .animation(.snappy(duration: 0.25), value: model.reminderRepeats)
        .animation(.snappy(duration: 0.25), value: model.endingSoonEnabled)
    }

    /// The presets plus the current value when it isn't one of them, so an
    /// imported custom lead time still shows as selected.
    private var noticeChoices: [TimeInterval] {
        Self.notices.contains(model.endingSoonNotice) ? Self.notices : (Self.notices + [model.endingSoonNotice]).sorted()
    }

    private var legend: [(symbol: String, text: String, warning: Bool)] {
        [
            ("bell", model.reminderEnabled
                ? (model.reminderRepeats ? L("Every %@", SessionController.humanDuration(model.reminderAfter))
                                         : L("Once, after %@", SessionController.humanDuration(model.reminderAfter)))
                : L("Reminder off"), false),
            ("clock", model.endingSoonEnabled ? L("%@ before the end", SessionController.humanDuration(model.endingSoonNotice)) : L("No warning"), true),
            ("stop.circle", model.notifyOnEnd ? L("When it ends on its own") : L("Ends silently"), false),
        ]
    }

    /// The notification a marker stands for, in the words the app sends.
    private func banner(for kind: ReminderTimeline.Kind, in timeline: ReminderTimeline) -> NotificationBanner.Content {
        switch kind {
        case .reminder:
            let at = timeline.first(.reminder)?.offset ?? model.reminderAfter
            let elapsed = SessionController.humanDuration(at)
            return .init(
                title: L("Pervigil is still keeping your Mac awake"),
                body: model.reminderRepeats ? L("Your Mac is still awake. It's been %@.", elapsed) : L("Your Mac has been kept awake for %@.", elapsed),
                sound: model.reminderSound,
                on: timeline.first(.reminder) != nil)
        case .endingSoon:
            return .init(
                title: L("Pervigil stops soon"),
                body: L("Your keep-awake session ends in about %@.", SessionController.humanDuration(model.endingSoonNotice)),
                sound: model.reminderSound,
                on: timeline.first(.endingSoon) != nil)
        case .ended:
            return .init(
                title: L("Pervigil stopped"),
                body: L("Your keep-awake session has ended."),
                sound: model.reminderSound,
                on: model.notifyOnEnd)
        }
    }
}

/// One timed session as a bar, with a marker for every notification on it.
private struct TimelinePreview: View {
    let timeline: ReminderTimeline
    @Binding var length: TimeInterval
    @Binding var selected: ReminderTimeline.Kind
    let banner: NotificationBanner.Content
    let legend: [(symbol: String, text: String, warning: Bool)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(verbatim: L("On a timed session of")).font(.callout.weight(.semibold))
                Picker("", selection: $length) {
                    Text(verbatim: SettingsFormat.short(3600)).tag(TimeInterval(3600))
                    Text(verbatim: SettingsFormat.short(4 * 3600)).tag(TimeInterval(4 * 3600))
                    Text(verbatim: SettingsFormat.short(8 * 3600)).tag(TimeInterval(8 * 3600))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Spacer()
                Text(verbatim: L("Click a marker to preview it")).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.bottom, 30)

            GeometryReader { proxy in
                let width = proxy.size.width
                let soon = timeline.first(.endingSoon)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [.panelTileTop, .panelTileBottom], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 8)
                    if let soon {
                        Rectangle()
                            .fill(Color.panelAmberDot.opacity(0.85))
                            .frame(width: max(3, width * (1 - soon.offset / timeline.length)), height: 8)
                            .offset(x: width * soon.offset / timeline.length)
                    }
                    Circle().fill(Color.panelAccentSolid).frame(width: 12, height: 12).offset(x: -6)
                    ForEach(Array(timeline.markers.enumerated()), id: \.offset) { index, marker in
                        markerView(marker, index: index, width: width)
                    }
                }
                .frame(height: 24)
            }
            .frame(height: 24)
            .padding(.horizontal, 12)

            HStack {
                ForEach(0..<5, id: \.self) { quarter in
                    Text(verbatim: quarter == 0 ? "0" : SettingsFormat.short(timeline.length * Double(quarter) / 4))
                        .font(.system(size: 10.5)).monospacedDigit().foregroundStyle(.secondary)
                    if quarter < 4 { Spacer() }
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 4)

            HStack(alignment: .bottom, spacing: 16) {
                NotificationBanner(content: banner)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(legend, id: \.symbol) { item in
                        Label(item.text, systemImage: item.symbol)
                            .font(.caption)
                            .foregroundStyle(item.warning ? AnyShapeStyle(Color.panelAmberText) : AnyShapeStyle(.secondary))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 16)
        }
        .padding(.vertical, 8)
        .animation(.snappy(duration: 0.3), value: timeline)
    }

    @ViewBuilder
    private func markerView(_ marker: ReminderTimeline.Marker, index: Int, width: CGFloat) -> some View {
        let x = width * marker.offset / timeline.length
        // Keep the warning clear of the end marker when it sits close by.
        let shown = marker.kind == .endingSoon ? min(x, width - 30) : x
        let isFirstOfKind = timeline.markers.firstIndex { $0.kind == marker.kind } == index
        let chosen = selected == marker.kind && isFirstOfKind
        let reminders = timeline.markers.filter { $0.kind == .reminder }.count
        Button { selected = marker.kind } label: {
            ZStack {
                Circle().fill(marker.kind == .ended ? Color.primary : Color(nsColor: .windowBackgroundColor))
                Circle().strokeBorder(stroke(marker.kind), lineWidth: marker.kind == .ended ? 0 : 1.5)
                Image(systemName: symbol(marker.kind))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(marker.kind == .ended ? Color(nsColor: .windowBackgroundColor) : stroke(marker.kind))
            }
            .frame(width: 22, height: 22)
            .scaleEffect(chosen ? 1.2 : 1)
            .overlay(alignment: .top) {
                if marker.kind != .reminder || reminders <= 8 || index % 2 == 0 {
                    Text(verbatim: label(marker))
                        .font(.system(size: 10.5)).monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .offset(y: -18)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: shown - 11)
        .help(label(marker))
        .accessibilityLabel(label(marker))
    }

    private func label(_ marker: ReminderTimeline.Marker) -> String {
        switch marker.kind {
        case .reminder: SettingsFormat.short(marker.offset)
        case .endingSoon: L("%@ left", SettingsFormat.short(timeline.length - marker.offset))
        case .ended: SettingsFormat.short(marker.offset)
        }
    }

    private func symbol(_ kind: ReminderTimeline.Kind) -> String {
        switch kind {
        case .reminder: "bell.fill"
        case .endingSoon: "clock"
        case .ended: "stop.fill"
        }
    }

    private func stroke(_ kind: ReminderTimeline.Kind) -> Color {
        kind == .endingSoon ? .panelAmberDot : .panelAccentSolid
    }
}

/// A macOS notification banner, drawn: what the user will actually see.
struct NotificationBanner: View {
    struct Content { var title: String; var body: String; var sound: Bool; var on: Bool }
    let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            MarkTile(size: 32, brand: true)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: content.title).font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 6)
                    Text(verbatim: L("now")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Text(verbatim: content.body).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                if !content.on {
                    Text(verbatim: L("This notification is off.")).font(.caption).foregroundStyle(.secondary)
                } else if content.sound {
                    Label(L("With sound"), systemImage: "speaker.wave.2").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(width: 340, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        .opacity(content.on ? 1 : 0.5)
        .accessibilityElement(children: .combine)
    }
}
