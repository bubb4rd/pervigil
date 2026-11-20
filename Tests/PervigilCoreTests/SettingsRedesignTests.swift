import Foundation
import Testing
@testable import PervigilCore

// MARK: - Reminder timeline

private func timeline(
    length: TimeInterval = 4 * 3600,
    reminder: Bool = true,
    after: TimeInterval = 3600,
    repeats: Bool = false,
    soon: Bool = true,
    notice: TimeInterval = 300,
    end: Bool = true
) -> ReminderTimeline {
    ReminderTimeline.make(
        length: length, reminderEnabled: reminder, reminderAfter: after, reminderRepeats: repeats,
        endingSoonEnabled: soon, endingSoonNotice: notice, notifyOnEnd: end)
}

@Test func oneTimeReminderFiresOnceThenWarningThenEnd() {
    let t = timeline()
    let kinds: [ReminderTimeline.Kind] = [.reminder, .endingSoon, .ended]
    #expect(t.markers.map(\.kind) == kinds)
    let expected: [TimeInterval] = [3600, 14_100, 14_400]
    #expect(t.markers.map(\.offset) == expected)
}

@Test func repeatingReminderFiresEveryIntervalBeforeTheEnd() {
    let t = timeline(after: 3600, repeats: true, soon: false, end: false)
    let expected: [TimeInterval] = [3600, 7200, 10800]
    #expect(t.markers.map(\.offset) == expected)
}

@Test func reminderAtOrAfterTheEndIsNotShown() {
    #expect(timeline(length: 3600, after: 3600, soon: false, end: false).markers.isEmpty)
    #expect(timeline(length: 1800, after: 3600, soon: false, end: false).markers.isEmpty)
}

@Test func warningLongerThanTheSessionIsDropped() {
    let t = timeline(length: 300, reminder: false, notice: 600)
    let kinds: [ReminderTimeline.Kind] = [.ended]
    #expect(t.markers.map(\.kind) == kinds)
}

@Test func offSettingsLeaveAnEmptyTimeline() {
    #expect(timeline(reminder: false, soon: false, end: false).markers.isEmpty)
}

@Test func shortRepeatsAreCapped() {
    let t = timeline(length: 8 * 3600, after: 60, repeats: true, soon: false, end: false)
    #expect(t.markers.count == ReminderTimeline.maxReminders)
}

@Test func markersStayInTimeOrder() {
    // A warning that lands before a late reminder still sorts first.
    let t = timeline(length: 3600, after: 3500, notice: 600)
    let kinds: [ReminderTimeline.Kind] = [.endingSoon, .reminder, .ended]
    #expect(t.markers.map(\.kind) == kinds)
    #expect(t.first(.reminder)?.offset == 3500)
}

// MARK: - Settings search

private let entries = [
    SettingsSearchEntry(page: "power", anchor: "lid", title: "Keep awake with the lid closed", group: "Closed-display mode", keywords: ["pmset", "clamshell"]),
    SettingsSearchEntry(page: "power", anchor: "battery", title: "Pause on low battery", group: "Battery guard"),
    SettingsSearchEntry(page: "keepAwake", anchor: "system", title: "Prevent system sleep"),
    SettingsSearchEntry(page: "automation", anchor: "end", title: "Sleep the Mac", group: "After the session ends"),
    SettingsSearchEntry(page: "general", anchor: "language", title: "App language"),
]

@Test func titlePrefixRanksAboveWordAboveGroupAndKeywords() {
    #expect(SettingsSearch.results(for: "sleep", in: entries).map(\.title) == ["Sleep the Mac", "Prevent system sleep"])
    #expect(SettingsSearch.results(for: "clamshell", in: entries).map(\.anchor) == ["lid"])
    #expect(SettingsSearch.results(for: "battery guard", in: entries).map(\.anchor) == ["battery"])
}

@Test func searchIgnoresCaseDiacriticsAndBlankQueries() {
    #expect(SettingsSearch.results(for: "  LÁNGUAGE ", in: entries).map(\.anchor) == ["language"])
    #expect(SettingsSearch.results(for: "   ", in: entries).isEmpty)
}

@Test func duplicateTitlesOnOnePageCollapse() {
    let dupes = entries + [SettingsSearchEntry(page: "power", anchor: "battery-2", title: "Pause on low battery")]
    #expect(SettingsSearch.results(for: "pause", in: dupes).count == 1)
}
