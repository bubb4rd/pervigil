import Foundation
import Testing
@testable import PervigilCore

/// A fixed clock in UTC so day boundaries are deterministic.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()
/// 2027-01-14 12:00:00 UTC.
private let noon = Date(timeIntervalSince1970: 1_799_928_000)

private func hhmm(_ date: Date) -> String {
    let parts = utc.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
}
private func mmss(_ interval: TimeInterval) -> String {
    let total = Int(interval)
    return String(format: "%d:%02d", total / 60, total % 60)
}
private func status(_ input: PanelInput) -> PanelStatus {
    PanelStatus.make(input, calendar: utc, formatTime: hhmm, formatDuration: mmss)
}

@Test func idleWithTriggersSaysWhatItWatches() {
    let s = status(PanelInput(now: noon, isActive: false, triggersEnabled: true, ruleCount: 4))
    #expect(s.state == .canSleep)
    #expect(s.title == "Can sleep")
    #expect(s.subtitle == "Watching 4 triggers")
    #expect(s.stop == nil)
    #expect(!s.heldByAutomation)
    #expect(status(PanelInput(now: noon, isActive: false, triggersEnabled: true, ruleCount: 1)).subtitle == "Watching 1 trigger")
}

@Test func idleWithoutTriggersPointsAtTheControls() {
    let paused = status(PanelInput(now: noon, isActive: false, triggersEnabled: true, triggersPaused: true, ruleCount: 4))
    #expect(paused.subtitle == "Press the mark or pick a duration")
    #expect(status(PanelInput(now: noon, isActive: false)).subtitle == "Press the mark or pick a duration")
}

@Test func timedSessionShowsEndTimeCountdownAndProgress() {
    let s = status(PanelInput(now: noon, isActive: true, remaining: 2_760, totalDuration: 3_600))
    #expect(s.state == .awake)
    #expect(s.title == "Awake")
    #expect(s.subtitle == "Stops at 12:46")
    #expect(s.countdown == 2_760)
    #expect(abs((s.progress ?? 0) - 2_760.0 / 3_600) < 0.0001)
    #expect(s.stop == .stopSession)
    #expect(s.reasons.isEmpty)
}

@Test func timedSessionPastMidnightSaysTomorrow() {
    // 12:00 + 20 h lands on 08:00 the next day.
    let s = status(PanelInput(now: noon, isActive: true, remaining: 20 * 3_600, totalDuration: 20 * 3_600))
    #expect(s.subtitle == "Stops at 08:00 tomorrow")
}

@Test func indefiniteSessionShowsHowLongItHasRun() {
    let s = status(PanelInput(now: noon, isActive: true, elapsed: 360))
    #expect(s.subtitle == "No time limit, on for 6:00")
    #expect(s.countdown == nil)
    #expect(s.progress == nil)
}

@Test func triggerHeldSessionShowsReasonsAndSetsTriggersAside() {
    let reasons = [PanelReason(kind: .agent, source: .agent("claude"), label: "Claude Code is working", id: "a")]
    let s = status(PanelInput(now: noon, isActive: true, triggersEnabled: true, ruleCount: 4, reasons: reasons))
    #expect(s.heldByAutomation)
    #expect(s.subtitle == nil)
    #expect(s.reasons == reasons)
    #expect(s.stop == .setTriggersAside)
}

@Test func leaseHeldSessionEndsLeases() {
    let s = status(PanelInput(now: noon, isActive: true, leaseHeld: true))
    #expect(s.heldByAutomation)
    #expect(s.stop == .endLeases)
    #expect(s.subtitle == "Held by your triggers")
}

@Test func batteryNearTheLimitWarnsWithANextStep() {
    let reasons = [PanelReason(kind: .agent, source: .agent("claude"), label: "x", id: "a")]
    let s = status(PanelInput(
        now: noon, isActive: true, triggersEnabled: true, ruleCount: 2, reasons: reasons,
        batteryPercent: 22, onBattery: true, batteryGuardOn: true, batteryThreshold: 20))
    #expect(s.tone == .warning)
    #expect(s.title == "Awake")
    #expect(s.subtitle == "Battery 22%. Sleeps at 20%.")
    #expect(s.detail == "Plug in to keep going.")
    #expect(s.reasons.isEmpty)
    #expect(s.tiles.battery == "2% to go")
    #expect(s.tiles.batteryWarning)
}

@Test func batteryWellAboveTheLimitDoesNotWarn() {
    let s = status(PanelInput(now: noon, isActive: true, elapsed: 60,
        batteryPercent: 76, onBattery: true, batteryGuardOn: true, batteryThreshold: 20))
    #expect(s.tone == .normal)
    #expect(s.tiles.battery == "76%, sleeps at 20%")
    #expect(!s.tiles.batteryWarning)
}

@Test func batteryPauseKeepsTheTitleClearAndOffersAWayOut() {
    let s = status(PanelInput(now: noon, isActive: false, pausedByBattery: true,
        batteryPercent: 18, onBattery: true, batteryGuardOn: true, batteryThreshold: 20))
    #expect(s.state == .paused)
    #expect(s.title == "Paused")
    #expect(s.subtitle == "Battery below 20%.")
    #expect(s.detail == "Plug in to resume.")
    #expect(s.stop == .endPausedSession)
    #expect(s.tiles.battery == "Paused, 18%")
}

@Test func thermalPauseExplainsItself() {
    let s = status(PanelInput(now: noon, isActive: false, pausedByThermal: true))
    #expect(s.state == .paused)
    #expect(s.subtitle == "Running hot, letting the Mac cool down")
    #expect(s.detail == nil)
}

@Test func tileValuesFollowTheirSettings() {
    let s = status(PanelInput(now: noon, isActive: true, elapsed: 1,
        hasBattery: true, batteryPercent: 90, onBattery: false, batteryGuardOn: true,
        lidOn: true, lidOnlyWhileAwake: true, preventDisplaySleep: true, dimsWhenIdle: true,
        stayActiveMethod: "F15"))
    #expect(s.tiles.lid == "During sessions")
    #expect(s.tiles.battery == "Plugged in")
    #expect(s.tiles.display == "On, dims when idle")
    #expect(s.tiles.stayActive == "F15")
    #expect(s.detail == "Lid can close")

    let off = status(PanelInput(now: noon, isActive: false, hasBattery: false))
    #expect(off.tiles.lid == "Sleeps")
    #expect(off.tiles.battery == "No battery")
    #expect(off.tiles.display == "Can sleep")
    #expect(off.tiles.stayActive == "Off")
}

// MARK: - Reasons

@Test func reasonsPutWorkingAgentsFirstThenTriggersThenLeases() {
    let states = [
        RuleState(rule: .micInUse(MicInUseRule()), satisfied: true, inGrace: false),
        RuleState(rule: .agentActivity(AgentRule()), satisfied: true, inGrace: false, details: [
            RuleDetail(label: "claude (pervigil)", active: true, agent: "claude"),
            RuleDetail(label: "codex (api)", active: false, agent: "codex"),
            RuleDetail(label: "claude (other)", active: true, agent: "claude"),
        ]),
        RuleState(rule: .gaming, satisfied: false, inGrace: false),
    ]
    let zoom = TriggerSource.app(bundleID: "us.zoom.xos", bundlePath: nil, pid: 42)
    let leases = [LeaseSummary(id: "l1", owner: "o", tool: "Claude", task: "run the migration suite",
                               expiresAt: noon.addingTimeInterval(600))]
    let reasons = PanelStatus.reasons(states: states, leases: leases, context: PanelSourceContext(micApp: zoom))
    #expect(reasons.map(\.kind) == [.agent, .call, .lease])
    #expect(reasons[0].source == .agent("claude"))
    #expect(reasons[0].label == "Claude Code is working")
    #expect(reasons[1].source == zoom)
    #expect(reasons[1].label == "On a call")
    #expect(reasons[2].source == .agent("claude"))
    #expect(reasons[2].label == "Lease: run the migration suite")
}

@Test func agentGraceBecomesOneCountdownReason() {
    let states = [RuleState(rule: .agentActivity(AgentRule()), satisfied: true, inGrace: true, graceRemaining: 158,
                            details: [RuleDetail(label: "claude", active: false, agent: "claude")])]
    let reasons = PanelStatus.reasons(states: states, leases: [])
    #expect(reasons.count == 1)
    #expect(reasons[0].kind == .grace)
    #expect(reasons[0].countdown == 158)
}

@Test func reasonsFallBackToSymbolsWithoutAKnownApp() {
    let states = [
        RuleState(rule: .mediaInUse(.camera), satisfied: true, inGrace: false),
        RuleState(rule: .gaming, satisfied: true, inGrace: false),
        RuleState(rule: .vpnConnected, satisfied: true, inGrace: false),
    ]
    let reasons = PanelStatus.reasons(states: states, leases: [
        LeaseSummary(id: "x", owner: "o", tool: "make", task: "build", expiresAt: noon),
    ])
    #expect(reasons.map(\.source) == [
        .symbol("video"), .symbol("gamecontroller"), .symbol("lock.shield"), .symbol("clock.badge.checkmark"),
    ])
}

@Test func rowSourcesNameTheAppOrPlace() {
    let context = PanelSourceContext(micApp: .app(bundleID: "us.zoom.xos", bundlePath: nil, pid: 1),
                                     gameApp: .app(bundleID: "com.game", bundlePath: nil, pid: 2))
    #expect(PanelStatus.rowSource(for: .micInUse(MicInUseRule()), context: context) == context.micApp)
    #expect(PanelStatus.rowSource(for: .gaming, context: context) == context.gameApp)
    #expect(PanelStatus.rowSource(for: .app(AppRule(bundleID: "com.apple.Safari")), context: context)
        == .app(bundleID: "com.apple.Safari", bundlePath: nil, pid: nil))
    let folder = URL(fileURLWithPath: "/tmp/Downloads")
    #expect(PanelStatus.rowSource(for: .downloadInFolder(folder), context: context) == .file(folder))
    #expect(PanelStatus.rowSource(for: .vpnConnected, context: context) == nil)
}

@Test func agentNamesUseTheMakersSpelling() {
    #expect(AgentNames.displayName("claude") == "Claude Code")
    #expect(AgentNames.displayName("cursor-agent") == "Cursor")
    #expect(AgentNames.displayName("newtool") == "Newtool")
}
