import Testing
import Foundation
@testable import PervigilCore

// System sleep stand-down and exit accounting: a session must not re-take an
// assertion in a dark wake, and the decision log must close sessions where
// they really ended so awake stats match what the Mac actually held.

private final class SleepFakeAssertions: PowerAsserting {
    private(set) var held: Set<PowerAssertionKind> = []
    func apply(_ kinds: Set<PowerAssertionKind>, reason: String) { held = kinds }
}

private final class SleepGate: TriggerEvaluating {
    var satisfied = false
    func isSatisfied() -> Bool { satisfied }
}

@MainActor
private final class SleepClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) { now.addTimeInterval(seconds) }
}

@MainActor
private func makeSession() -> (SessionController, SleepFakeAssertions, SleepClock) {
    let clock = SleepClock()
    let assertions = SleepFakeAssertions()
    let session = SessionController(assertions: assertions, now: { clock.now })
    return (session, assertions, clock)
}

private func tempLogURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("pervigil-sleep-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("decision-log.jsonl")
}

private func makeStore(_ url: URL) -> FileLogStore {
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    return FileLogStore(fileURL: url)
}

// MARK: - Sleep stand-down

@Test @MainActor func sleepStopsAManualSessionAndLogsIt() {
    let (session, assertions, clock) = makeSession()
    session.start(mode: .indefinite)
    #expect(!assertions.held.isEmpty)

    clock.advance(60)
    session.systemWillSleep()

    #expect(!session.isActive)
    #expect(session.pausedBySleep)
    #expect(assertions.held.isEmpty)
    let last = session.log.events.last
    #expect(last?.began == false)
    #expect(last?.kind == .sleepPaused)
    #expect(last?.reason == "Paused, the Mac went to sleep")
}

@Test @MainActor func darkWakeTicksHoldNothingUntilAFullWake() {
    let (session, assertions, clock) = makeSession()
    session.start(mode: .indefinite)
    session.systemWillSleep()

    // A maintenance dark wake: the ticker runs, but nothing may be held.
    for _ in 0 ..< 5 {
        clock.advance(1)
        session.reconcile(now: clock.now, battery: .discharging(25))
    }
    #expect(!session.isActive)
    #expect(assertions.held.isEmpty)

    clock.advance(3600)
    session.systemDidWake()
    session.reconcile(now: clock.now)

    #expect(session.isActive)
    #expect(!assertions.held.isEmpty)
    #expect(session.log.events.last?.reason == "Resumed after sleep")
}

@Test @MainActor func resumedManualSessionKeepsItsOriginalStart() {
    let (session, _, clock) = makeSession()
    session.start(mode: .indefinite)
    let started = session.startedAt
    clock.advance(120)
    session.systemWillSleep()
    clock.advance(600)
    session.systemDidWake()
    session.reconcile(now: clock.now)
    #expect(session.startedAt == started)
}

@Test @MainActor func timedSessionThatExpiredDuringSleepEndsOnWake() {
    let (session, assertions, clock) = makeSession()
    session.start(mode: .timed(duration: 300))
    clock.advance(60)
    session.systemWillSleep()
    clock.advance(3600)
    session.systemDidWake()
    session.reconcile(now: clock.now)

    #expect(!session.isActive)
    #expect(assertions.held.isEmpty)
    #expect(session.log.events.last?.reason == "Timed session ended")
}

@Test @MainActor func triggersCannotEngageDuringADarkWake() {
    let (session, assertions, clock) = makeSession()
    let gate = SleepGate()
    session.triggerGate = gate
    session.systemWillSleep()

    gate.satisfied = true
    clock.advance(1)
    session.reconcile(now: clock.now)
    #expect(!session.isActive)
    #expect(assertions.held.isEmpty)
    #expect(session.log.events.isEmpty)

    session.systemDidWake()
    clock.advance(1)
    session.reconcile(now: clock.now)
    #expect(session.isActive)
    #expect(session.log.events.last?.kind == .triggerFired)
}

@Test @MainActor func sleepStopsATriggerSessionWithoutRememberingIt() {
    let (session, _, clock) = makeSession()
    let gate = SleepGate()
    session.triggerGate = gate
    gate.satisfied = true
    session.reconcile(now: clock.now)
    #expect(session.isActive)

    clock.advance(30)
    session.systemWillSleep()
    #expect(!session.isActive)
    #expect(session.log.events.last?.kind == .sleepPaused)

    // Trigger released while asleep: waking must not resurrect the session.
    gate.satisfied = false
    session.systemDidWake()
    clock.advance(1)
    session.reconcile(now: clock.now)
    #expect(!session.isActive)
}

@Test @MainActor func explicitStartEndsTheSleepStandDown() {
    let (session, assertions, _) = makeSession()
    session.systemWillSleep()
    session.start(mode: .indefinite, cause: .command)
    #expect(!session.pausedBySleep)
    #expect(session.isActive)
    #expect(!assertions.held.isEmpty)
}

@Test @MainActor func repeatedSleepNoticesLogOnce() {
    let (session, _, _) = makeSession()
    session.start(mode: .indefinite)
    session.systemWillSleep()
    session.systemWillSleep()
    #expect(session.log.events.filter { $0.kind == .sleepPaused }.count == 1)
}

@Test @MainActor func sleepWhileIdleLogsNothing() {
    let (session, _, _) = makeSession()
    session.systemWillSleep()
    #expect(session.log.events.isEmpty)
    #expect(session.pausedBySleep)
}

@Test func sleepPauseRaisesSessionEndedHooksAndExitRaisesNone() {
    #expect(EventHookPolicy.hookEvents(for: .sleepPaused) == [.sessionEnded])
    #expect(EventHookPolicy.hookEvents(for: .appExited).isEmpty)
}

// MARK: - App exit

@Test @MainActor func appExitLogsTheEndWithoutChangingState() {
    let (session, assertions, clock) = makeSession()
    session.start(mode: .indefinite)
    clock.advance(90)
    session.recordAppExit()

    let last = session.log.events.last
    #expect(last?.began == false)
    #expect(last?.kind == .appExited)
    #expect(last?.reason == "Pervigil quit")
    // Teardown is the OS's job at exit; no end effects, no state change.
    #expect(session.isActive)
    #expect(!assertions.held.isEmpty)
}

@Test @MainActor func appExitWhileIdleLogsNothing() {
    let (session, _, _) = makeSession()
    session.recordAppExit()
    #expect(session.log.events.isEmpty)
}

// MARK: - Dangling sessions

@Test func danglingSessionClosesAtTheLastHeartbeat() {
    let start = Date(timeIntervalSince1970: 1000)
    let alive = Date(timeIntervalSince1970: 1600)
    let now = Date(timeIntervalSince1970: 9000)
    #expect(DanglingSession.closingDate(start: start, lastAlive: alive, now: now) == alive)
}

@Test func danglingSessionWithoutEvidenceClosesAtItsStart() {
    let start = Date(timeIntervalSince1970: 1000)
    let now = Date(timeIntervalSince1970: 9000)
    #expect(DanglingSession.closingDate(start: start, lastAlive: nil, now: now) == start)
    // A heartbeat from an earlier session says nothing about this one.
    let stale = Date(timeIntervalSince1970: 500)
    #expect(DanglingSession.closingDate(start: start, lastAlive: stale, now: now) == start)
}

@Test func danglingSessionNeverClosesInTheFuture() {
    let start = Date(timeIntervalSince1970: 1000)
    let future = Date(timeIntervalSince1970: 99_999)
    let now = Date(timeIntervalSince1970: 2000)
    #expect(DanglingSession.closingDate(start: start, lastAlive: future, now: now) == now)
}

@MainActor
@Test func persisterClosesADanglingStartAtItsHeartbeat() throws {
    let url = tempLogURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let store = makeStore(url)
    let crashed = DecisionLogPersister(store: store)
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    crashed.append(PersistedSessionEvent(date: start, began: true, reason: "Started manually", kind: .sessionStarted))
    crashed.heartbeat(at: start.addingTimeInterval(600))

    // Next launch: a fresh persister over the same files.
    let relaunched = DecisionLogPersister(store: FileLogStore(fileURL: url))
    let healed = try #require(relaunched.closeDanglingSession(
        reason: "Pervigil stopped unexpectedly", now: start.addingTimeInterval(7200)))
    #expect(healed.began == false)
    #expect(healed.kind == .appExited)
    #expect(healed.date == start.addingTimeInterval(600))

    let all = relaunched.loadAll()
    #expect(all.count == 2)
    #expect(all.last?.reason == "Pervigil stopped unexpectedly")
}

@MainActor
@Test func persisterLeavesACleanlyClosedLogAlone() {
    let url = tempLogURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let persister = DecisionLogPersister(store: makeStore(url))
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    persister.append(PersistedSessionEvent(date: start, began: true, reason: "a"))
    persister.append(PersistedSessionEvent(date: start.addingTimeInterval(60), began: false, reason: "b"))
    #expect(persister.closeDanglingSession(reason: "x") == nil)
    #expect(persister.loadAll().count == 2)
}

@MainActor
@Test func persisterHandlesAMissingLog() {
    let url = tempLogURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let persister = DecisionLogPersister(store: makeStore(url))
    #expect(persister.closeDanglingSession(reason: "x") == nil)
}

@MainActor
@Test func heartbeatWritesAreThrottled() {
    let url = tempLogURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let persister = DecisionLogPersister(store: makeStore(url))
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    persister.heartbeat(at: t0)
    persister.heartbeat(at: t0.addingTimeInterval(10))
    #expect(persister.lastHeartbeat() == t0)
    persister.heartbeat(at: t0.addingTimeInterval(DecisionLogPersister.heartbeatInterval))
    #expect(persister.lastHeartbeat() == t0.addingTimeInterval(DecisionLogPersister.heartbeatInterval))
}

@Test func fileStoreTailReadsOnlyTheEnd() throws {
    let url = tempLogURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let store = makeStore(url)
    for i in 0 ..< 200 {
        let line = try #require(DecisionLogCodec.encodeLine(PersistedSessionEvent(
            date: Date(timeIntervalSince1970: TimeInterval(i)), began: i.isMultiple(of: 2), reason: "event \(i)")))
        store.append(line)
    }
    let tail = store.loadTail(maxBytes: 512)
    #expect(tail.count <= 512)
    #expect(DecisionLogCodec.decode(tail).last?.reason == "event 199")
}

// MARK: - Stats end to end

/// The Nov 2026 field logs: a crash mid-session followed by a relaunch used to
/// drop the crashed session entirely (the next start overwrote it). Healed,
/// it counts up to the last heartbeat.
@Test func healedCrashCountsTowardAwakeStats() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let day = Date(timeIntervalSince1970: 1_800_000_000 - 1_800_000_000.truncatingRemainder(dividingBy: 86_400))
    let start = day.addingTimeInterval(3600)
    let events = [
        PersistedSessionEvent(date: start, began: true, reason: "Triggers: AI agent working"),
        PersistedSessionEvent(
            date: DanglingSession.closingDate(start: start, lastAlive: start.addingTimeInterval(1800), now: start.addingTimeInterval(1900)),
            began: false, reason: "Pervigil stopped unexpectedly", kind: .appExited),
        PersistedSessionEvent(date: start.addingTimeInterval(1900), began: true, reason: "Triggers: AI agent working"),
        PersistedSessionEvent(date: start.addingTimeInterval(2500), began: false, reason: "Trigger conditions ended"),
    ]
    let stats = AwakeStatsAggregator.summarize(
        events: events, now: start.addingTimeInterval(4000), dayCount: 1, calendar: calendar)
    #expect(stats.totalHeldSeconds == 1800 + 600)
}
