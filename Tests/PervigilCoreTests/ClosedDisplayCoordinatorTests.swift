import Testing
import Foundation
@testable import PervigilCore

/// Baseline: feature on, helper installed (so flips are silent), idle, nothing
/// held, setting off. Each test varies only what it is about.
private func conditions(
    onlyWhileBrewing: Bool = true,
    brewing: Bool = false,
    helperInstalled: Bool = true,
    automationHolding: Bool = false,
    automationAuthorized: Bool = true,
    automationFailed: Bool = false,
    settingIsOn: Bool? = false,
    settingIsBusy: Bool = false,
    fallbackDeclined: Bool = false
) -> ClosedDisplayCoordinator.Conditions {
    .init(
        onlyWhileBrewing: onlyWhileBrewing,
        brewing: brewing,
        helperInstalled: helperInstalled,
        automationHolding: automationHolding,
        automationAuthorized: automationAuthorized,
        automationFailed: automationFailed,
        settingIsOn: settingIsOn,
        settingIsBusy: settingIsBusy,
        fallbackDeclined: fallbackDeclined
    )
}

@MainActor
@Test func tickDoesNothingWhileTheFeatureIsOff() {
    let coordinator = ClosedDisplayCoordinator()
    #expect(coordinator.tick(conditions(onlyWhileBrewing: false, brewing: true)).isEmpty)
}

@MainActor
@Test func tickPulsesTheAutomationWithTheSessionState() {
    let coordinator = ClosedDisplayCoordinator()
    #expect(coordinator.tick(conditions(brewing: true)).contains(.runAutoTick(brewing: true)))
    #expect(coordinator.tick(conditions(brewing: false)).contains(.runAutoTick(brewing: false)))
}

@MainActor
@Test func needsHelperIsSurfacedOncePerRun() {
    let coordinator = ClosedDisplayCoordinator()
    let start = conditions(brewing: true, helperInstalled: false, automationAuthorized: false)
    #expect(coordinator.tick(start).contains(.surfaceNeedsAuthorization))
    // Not again this session...
    #expect(!coordinator.tick(start).contains(.surfaceNeedsAuthorization))
    // ...nor on the next one: a notice per session start would be its own nag.
    _ = coordinator.tick(conditions(brewing: false, helperInstalled: false, automationAuthorized: false))
    #expect(!coordinator.tick(start).contains(.surfaceNeedsAuthorization))
}

@MainActor
@Test func needsHelperIsSilentWithTheHelperAnAuthorizationOrADecline() {
    let withHelper = ClosedDisplayCoordinator()
    #expect(!withHelper.tick(
        conditions(brewing: true, helperInstalled: true, automationAuthorized: false)
    ).contains(.surfaceNeedsAuthorization))

    let alreadyAuthorized = ClosedDisplayCoordinator()
    #expect(!alreadyAuthorized.tick(
        conditions(brewing: true, helperInstalled: false, automationAuthorized: true)
    ).contains(.surfaceNeedsAuthorization))

    // The user said no to the password once; that answer stands across
    // launches (the flag is persisted), so a fresh coordinator stays quiet.
    let declined = ClosedDisplayCoordinator()
    #expect(!declined.tick(
        conditions(brewing: true, helperInstalled: false, automationAuthorized: false, fallbackDeclined: true)
    ).contains(.surfaceNeedsAuthorization))
}

@MainActor
@Test func aFailedEngageChecksTheHelperOnceForEachFailure() {
    let coordinator = ClosedDisplayCoordinator()
    let failing = conditions(automationFailed: true)
    #expect(coordinator.tick(failing).contains(.verifyHelper))
    #expect(!coordinator.tick(failing).contains(.verifyHelper))
    // Recovering and failing again is a new edge worth checking.
    _ = coordinator.tick(conditions(automationFailed: false))
    #expect(coordinator.tick(failing).contains(.verifyHelper))
}

@MainActor
@Test func aFailedEngageWithoutTheHelperIsNotTheDaemonsFault() {
    let coordinator = ClosedDisplayCoordinator()
    #expect(!coordinator.tick(
        conditions(helperInstalled: false, automationFailed: true)
    ).contains(.verifyHelper))
}

@MainActor
@Test func engageAndReleaseAreMirroredAfterTheHelperHasACycle() {
    let coordinator = ClosedDisplayCoordinator()
    _ = coordinator.tick(conditions())
    let engaged = coordinator.tick(conditions(brewing: true, automationHolding: true))
    #expect(engaged.contains(.refreshThenEnforce(delay: ClosedDisplayCoordinator.mirrorDelay)))
    // Steady state while held: nothing to mirror.
    let held = coordinator.tick(conditions(brewing: true, automationHolding: true, settingIsOn: true))
    #expect(!held.contains(.refreshThenEnforce(delay: ClosedDisplayCoordinator.mirrorDelay)))
    // The release leaves a setting that looks like a foreign hold, and the
    // mirroring tick must not act on it: that reading is the pre-release one
    // until the re-read lands.
    let released = coordinator.tick(conditions(automationHolding: false, settingIsOn: true))
    #expect(released.contains(.refreshThenEnforce(delay: ClosedDisplayCoordinator.mirrorDelay)))
    #expect(!released.contains(.clearForeignHold(origin: .automation)))
}

@MainActor
@Test func idleTicksReReadTheSettingOnTheirOwnCadence() {
    let coordinator = ClosedDisplayCoordinator(pollInterval: 3)
    for _ in 0..<2 {
        #expect(!coordinator.tick(conditions()).contains(.refreshThenEnforce(delay: nil)))
    }
    #expect(coordinator.tick(conditions()).contains(.refreshThenEnforce(delay: nil)))
    // The counter restarts, so the next read is another full interval away.
    #expect(!coordinator.tick(conditions()).contains(.refreshThenEnforce(delay: nil)))
}

@MainActor
@Test func theUnattendedReReadWaitsForAnIdleMac() {
    let coordinator = ClosedDisplayCoordinator(pollInterval: 2)
    for _ in 0..<5 {
        #expect(!coordinator.tick(conditions(brewing: true)).contains(.refreshThenEnforce(delay: nil)))
    }
}

@MainActor
@Test func aMirroredChangeRestartsThePollCounter() {
    let coordinator = ClosedDisplayCoordinator(pollInterval: 3)
    _ = coordinator.tick(conditions())
    _ = coordinator.tick(conditions())
    // An engage lands on what would have been the last tick before a re-read.
    _ = coordinator.tick(conditions(automationHolding: true))
    // Without the restart the very next tick would cross the threshold, so this
    // is the tick that pins it.
    for _ in 0..<2 {
        #expect(!coordinator.tick(conditions(automationHolding: true))
            .contains(.refreshThenEnforce(delay: nil)))
    }
}

@MainActor
@Test func anIdleForeignHoldIsClearedOnce() {
    let coordinator = ClosedDisplayCoordinator()
    let foreign = conditions(settingIsOn: true)
    #expect(coordinator.tick(foreign).contains(.clearForeignHold(origin: .automation)))
    // A write that doesn't take isn't retried every second.
    #expect(!coordinator.tick(foreign).contains(.clearForeignHold(origin: .automation)))
}

@MainActor
@Test func aForeignHoldIsLeftAloneDuringASession() {
    let coordinator = ClosedDisplayCoordinator()
    let brewingWithHold = conditions(brewing: true, settingIsOn: true)
    #expect(!coordinator.tick(brewingWithHold).contains(.clearForeignHold(origin: .automation)))
}

@MainActor
@Test func aSessionRearmsTheForeignHoldClear() {
    let coordinator = ClosedDisplayCoordinator()
    #expect(coordinator.tick(conditions(settingIsOn: true)).contains(.clearForeignHold(origin: .automation)))
    // The session hands the setting back, and its release may restore a hold
    // that was set outside the automation.
    _ = coordinator.tick(conditions(brewing: true, settingIsOn: true))
    #expect(coordinator.tick(conditions(settingIsOn: true)).contains(.clearForeignHold(origin: .automation)))
}

@MainActor
@Test func withoutTheHelperAnUnattendedClearNeverHappens() {
    // Clearing without the helper takes a password, and nobody asked for one.
    let coordinator = ClosedDisplayCoordinator()
    let foreign = conditions(helperInstalled: false, settingIsOn: true)
    for _ in 0..<5 {
        let actions = coordinator.tick(foreign)
        #expect(!actions.contains(.clearForeignHold(origin: .automation)))
        #expect(!actions.contains(.clearForeignHold(origin: .userAction)))
    }
    #expect(coordinator.enforce(foreign) == nil)
}

@MainActor
@Test func aUserActionMayClearWithoutTheHelper() {
    // The user just toggled the feature: they are at the keyboard, so this
    // clear may show the password dialog.
    let coordinator = ClosedDisplayCoordinator()
    let action = coordinator.enforce(
        conditions(helperInstalled: false, settingIsOn: true),
        allowPrompt: true
    )
    #expect(action == .clearForeignHold(origin: .userAction))
}

@MainActor
@Test func enforcementWaitsForAPendingReRead() {
    let coordinator = ClosedDisplayCoordinator()
    let foreign = conditions(settingIsOn: true)
    let token = coordinator.beginRefresh()
    // The cached value is the pre-change one until the read lands, so acting on
    // it now would enforce against a stale setting.
    #expect(coordinator.enforce(foreign) == nil)
    // The tick still pulses the automation, it just doesn't enforce.
    let ticked = coordinator.tick(foreign)
    #expect(ticked.contains(.runAutoTick(brewing: false)))
    #expect(!ticked.contains(.clearForeignHold(origin: .automation)))
    #expect(coordinator.endRefresh(token, settingIsOn: true))
    #expect(coordinator.enforce(foreign) == .clearForeignHold(origin: .automation))
}

@MainActor
@Test func enforcementWaitsWhileAPromptIsOnScreen() {
    let coordinator = ClosedDisplayCoordinator()
    #expect(coordinator.enforce(conditions(settingIsOn: true, settingIsBusy: true)) == nil)
}

@MainActor
@Test func asupersededReReadLeavesTheLatchForTheNewerOne() {
    let coordinator = ClosedDisplayCoordinator()
    let old = coordinator.beginRefresh()
    let new = coordinator.beginRefresh()
    #expect(!coordinator.refreshIsCurrent(old))
    #expect(coordinator.refreshIsCurrent(new))
    // The older read finishing must not lift the latch the newer one is holding.
    #expect(!coordinator.endRefresh(old, settingIsOn: false))
    #expect(coordinator.enforce(conditions(settingIsOn: true)) == nil)
    #expect(coordinator.endRefresh(new, settingIsOn: true))
    #expect(coordinator.enforce(conditions(settingIsOn: true)) == .clearForeignHold(origin: .automation))
}

@MainActor
@Test func aConfirmedOffSettingArmsTheClearAgain() {
    let coordinator = ClosedDisplayCoordinator()
    #expect(coordinator.tick(conditions(settingIsOn: true)).contains(.clearForeignHold(origin: .automation)))
    // The read confirms the clear took, so a hold taken later in this same idle
    // stretch is still caught.
    let token = coordinator.beginRefresh()
    #expect(coordinator.endRefresh(token, settingIsOn: false))
    #expect(coordinator.enforce(conditions(settingIsOn: true)) == .clearForeignHold(origin: .automation))
}

@MainActor
@Test func anUnreadableSettingLeavesTheLatchAlone() {
    let coordinator = ClosedDisplayCoordinator()
    #expect(coordinator.tick(conditions(settingIsOn: true)).contains(.clearForeignHold(origin: .automation)))
    let token = coordinator.beginRefresh()
    // nil is "couldn't read", not "confirmed off": nothing proves the clear took.
    #expect(coordinator.endRefresh(token, settingIsOn: nil))
    #expect(coordinator.enforce(conditions(settingIsOn: true)) == nil)
}

@MainActor
@Test func turningTheFeatureOnArmsTheClear() {
    let coordinator = ClosedDisplayCoordinator()
    #expect(coordinator.tick(conditions(settingIsOn: true)).contains(.clearForeignHold(origin: .automation)))
    coordinator.rearmForeignHoldClear()
    #expect(coordinator.enforce(conditions(settingIsOn: true)) == .clearForeignHold(origin: .automation))
}
