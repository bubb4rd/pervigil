import SwiftUI
import Charts
import AppKit
import PervigilCore

/// Activity: what is keeping the Mac awake right now (every app's live power
/// assertions, not just Pervigil's), the week, and why Pervigil acted.
struct SettingsActivityPage: View {
    @Bindable var model: AppModel

    /// Live assertions, refreshed while the page is mounted. Cleared on
    /// disappear so a closed Preferences window does not keep the snapshot.
    @State private var assertions: [PowerAssertionInfo] = []
    @State private var filter: LogFilter = .all

    private enum LogFilter: Hashable { case all, starts, stops }

    var body: some View {
        let relevant = assertions.filter { $0.effect != nil }
        Form {
            Section {
                NowSummary(assertions: relevant)
                ForEach(relevant) { assertion in
                    AssertionRow(assertion: assertion)
                }
            } header: {
                GroupHeader(title: nil) {
                    PageHeader(page: .activity, summary: L("What is keeping the Mac awake right now, how long it was held this week, and why Pervigil acted."))
                    HStack(spacing: 4) {
                        Text(verbatim: L("Keeping the Mac awake now"))
                        InfoButton(text: L("Every app's live power assertions, not just Pervigil's, the same data pmset -g assertions prints."))
                        Spacer()
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text(verbatim: L("Live")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .settingsAnchor("now")
            }

            Section {
                WeekChart(stats: model.awakeStats)
            } header: {
                GroupHeader(L("Awake this week"), info: L("How long Pervigil held the Mac awake each day, from the decision log. Battery drop is shown when both ends of a session had a reading."))
                    .settingsAnchor("week")
            }

            Section {
                let events = Array(model.session.log.events.reversed()).filter {
                    switch filter {
                    case .all: true
                    case .starts: $0.began
                    case .stops: !$0.began
                    }
                }
                if events.isEmpty {
                    Text("No session activity yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(groupedByDay(events).enumerated()), id: \.offset) { _, group in
                        Text(verbatim: group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(group.events) { event in
                            EventRow(event: event)
                        }
                    }
                }
            } header: {
                HStack(spacing: 4) {
                    Text(verbatim: L("Pervigil decisions"))
                    InfoButton(text: L("Why each session started or stopped, newest first. Saved on disk and restored after a relaunch."))
                    Spacer()
                    Picker("", selection: $filter) {
                        Text(verbatim: L("All")).tag(LogFilter.all)
                        Text(verbatim: L("Starts")).tag(LogFilter.starts)
                        Text(verbatim: L("Stops")).tag(LogFilter.stops)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .controlSize(.small)
                }
                .textCase(nil)
                .settingsAnchor("log")
            } footer: {
                sectionFooter("Why each session started or stopped, newest first. Saved on disk and restored after a relaunch.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            assertions = model.currentAssertions()
            model.refreshAwakeStats()
        }
        .onDisappear { assertions = [] }
        // The parent unmounts this page while the window is hidden; the
        // receive only exists while mounted, so the poll dies with the page.
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            assertions = model.currentAssertions()
        }
    }

    private struct DayGroup { let title: String; let events: [SessionEvent] }

    private func groupedByDay(_ events: [SessionEvent]) -> [DayGroup] {
        let calendar = Calendar.current
        var groups: [DayGroup] = []
        for event in events {
            let title: String
            if calendar.isDateInToday(event.date) {
                title = L("Today")
            } else if calendar.isDateInYesterday(event.date) {
                title = L("Yesterday")
            } else {
                title = event.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            }
            if groups.last?.title == title {
                groups[groups.count - 1] = DayGroup(title: title, events: groups[groups.count - 1].events + [event])
            } else {
                groups.append(DayGroup(title: title, events: [event]))
            }
        }
        return groups
    }
}

/// "3 apps are keeping the Mac awake", with their icons stacked.
private struct NowSummary: View {
    let assertions: [PowerAssertionInfo]

    var body: some View {
        HStack(spacing: 12) {
            if assertions.isEmpty {
                StateIcon(symbol: "moon", size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: L("Nothing is holding the Mac awake")).font(.system(size: 13.5, weight: .semibold))
                    Text(verbatim: L("It sleeps on its usual schedule.")).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                let apps = Array(Set(assertions.map(\.pid))).count
                HStack(spacing: -7) {
                    ForEach(Array(uniquePIDs.prefix(3).enumerated()), id: \.offset) { index, pid in
                        AssertionIcon(pid: pid, size: 30)
                            .zIndex(Double(3 - index))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: apps == 1 ? L("1 app is keeping the Mac awake") : L("%d apps are keeping the Mac awake", apps))
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(verbatim: L("%d prevent sleep, %d keep the display on", systemCount, displayCount))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var uniquePIDs: [Int32] {
        var seen = Set<Int32>()
        return assertions.map(\.pid).filter { seen.insert($0).inserted }
    }

    private var displayCount: Int { assertions.filter { $0.type.contains("Display") }.count }
    private var systemCount: Int { assertions.count - displayCount }
}

/// One live assertion: the owning app's icon, name, reason, and effect.
private struct AssertionRow: View {
    let assertion: PowerAssertionInfo

    var body: some View {
        let display = assertion.type.contains("Display")
        HStack(spacing: 10) {
            AssertionIcon(pid: assertion.pid, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: assertion.processName)
                if !assertion.name.isEmpty {
                    Text(verbatim: assertion.name)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                        .help(assertion.name)
                }
            }
            Spacer(minLength: 8)
            StatusPill(text: assertion.effect ?? assertion.type, tint: display ? .neutral : .on)
        }
    }
}

/// The app that owns an assertion, as macOS draws its icon; a gear for
/// daemons with no app.
private struct AssertionIcon: View {
    let pid: Int32
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon, app.bundleURL != nil {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color.gray, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Seven days of held-awake time as bars, with the totals beside them.
private struct WeekChart: View {
    let stats: AwakeStats

    var body: some View {
        let days = lastSevenDays
        if stats.totalHeldSeconds < 1 {
            Text("No held-awake time in the last week.").foregroundStyle(.secondary)
        } else {
            HStack(alignment: .top, spacing: 18) {
                Chart(days, id: \.start) { day in
                    BarMark(
                        x: .value(L("Day"), day.start, unit: .day),
                        y: .value(L("Hours"), day.held / 3600))
                    .foregroundStyle(Calendar.current.isDateInToday(day.start) ? Color.panelAccentSolid : Color.panelAccentSolid.opacity(0.35))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel { if let h = value.as(Double.self) { Text(verbatim: L("%dh", Int(h))) } }
                    }
                }
                .frame(height: 140)
                VStack(alignment: .leading, spacing: 12) {
                    kpi(held(stats.totalHeldSeconds), L("held this week"))
                    kpi(held(stats.totalHeldSeconds / 7), L("a day, on average"))
                    if let longest = days.max(by: { $0.held < $1.held }), longest.held > 0 {
                        kpi(held(longest.held), L("longest, on %@", longest.start.formatted(.dateTime.weekday(.wide))))
                    }
                }
                .frame(width: 130, alignment: .leading)
            }
            .padding(.vertical, 6)
        }
    }

    private struct Day { let start: Date; let held: TimeInterval }

    /// Today and the six days before it, zero-filled.
    private var lastSevenDays: [Day] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let held = stats.days.first { calendar.isDate($0.dayStart, inSameDayAs: start) }?.heldSeconds ?? 0
            return Day(start: start, held: held)
        }
    }

    private func kpi(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: value).font(.system(size: 19, weight: .semibold)).monospacedDigit()
            Text(verbatim: label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func held(_ seconds: TimeInterval) -> String {
        let total = PervigilSettings.displaySeconds(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? L("%dh %dm", h, m) : L("%dm", max(m, 0))
    }
}

/// One decision on the timeline: a filled play for a start, a stop square
/// for an end, with the time.
private struct EventRow: View {
    let event: SessionEvent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: event.began ? "play.circle.fill" : "stop.circle")
                .foregroundStyle(event.began ? Color.panelAccentSolid : Color.secondary)
                .frame(width: 24)
            Text(verbatim: event.reason)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer()
            Text(event.date, format: .dateTime.hour().minute())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
