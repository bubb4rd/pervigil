import Testing
import Foundation
@testable import PervigilCore

/// Stands in for `/usr/bin/osascript`: records every launch (each one is a
/// password dialog on a real Mac) and answers with a canned exit.
private final class OsascriptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _scripts: [String] = []
    var status: Int32 = 0
    var stderr = ""

    var scripts: [String] { lock.withLock { _scripts } }
    var launches: Int { scripts.count }

    var runner: OsascriptAdminPrompter.Runner {
        { [self] path, arguments in
            lock.withLock {
                #expect(path == "/usr/bin/osascript")
                _scripts.append(arguments.last ?? "")
                return (status, stderr)
            }
        }
    }
}

private func tempFlagURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("pervigil-admin-prompt-tests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent(name)
}

// MARK: - The prompter

@Test func automationIsRefusedWithoutLaunchingOsascript() {
    let osascript = OsascriptRecorder()
    let prompter = OsascriptAdminPrompter(runner: osascript.runner)
    #expect(prompter.runAsRoot("/usr/bin/true", feature: .sleepSetting, origin: .automation) == .refused)
    #expect(osascript.launches == 0)
}

@Test func aUserActionPromptSaysWhoIsAsking() throws {
    let osascript = OsascriptRecorder()
    let prompter = OsascriptAdminPrompter(runner: osascript.runner)
    #expect(prompter.runAsRoot(#"/bin/echo "hi""#, feature: .sleepWatchdog, origin: .userAction) == .succeeded)
    let script = try #require(osascript.scripts.first)
    #expect(script.contains("with administrator privileges"))
    #expect(script.contains("with prompt \"\(AdminPromptFeature.sleepWatchdog.reason)\""))
    #expect(script.contains(#"/bin/echo \"hi\""#)) // quotes escaped into the literal
}

@Test func everyFeatureHasAReasonNamingPervigil() {
    for feature in AdminPromptFeature.allCases {
        #expect(feature.reason.hasPrefix("Pervigil needs your password"))
        #expect(!feature.reason.contains("\""))
    }
}

@Test func prompterMapsOsascriptOutcomes() {
    #expect(OsascriptAdminPrompter.outcome(status: 0, stderr: "") == .succeeded)
    #expect(OsascriptAdminPrompter.outcome(status: 1, stderr: "execution error: User canceled. (-128)") == .cancelled)
    #expect(OsascriptAdminPrompter.outcome(status: 1, stderr: " pmset: nope \n") == .failed("pmset: nope"))
    let missing = OsascriptAdminPrompter(runner: { _, _ in nil })
    #expect(missing.runAsRoot("/usr/bin/true", feature: .awdlPause, origin: .userAction) == .launchFailed)
}

private final class RecordBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _records: [AdminPromptRecord] = []
    var records: [AdminPromptRecord] { lock.withLock { _records } }
    func append(_ record: AdminPromptRecord) { lock.withLock { _records.append(record) } }
}

@Test func theObserverSeesEveryAttempt() {
    let box = RecordBox()
    let osascript = OsascriptRecorder()
    let prompter = OsascriptAdminPrompter(runner: osascript.runner) { box.append($0) }
    _ = prompter.runAsRoot("/usr/bin/true", feature: .awdlPause, origin: .automation)
    _ = prompter.runAsRoot("/usr/bin/true", feature: .keyboardCleaner, origin: .userAction)
    #expect(box.records == [
        AdminPromptRecord(feature: .awdlPause, origin: .automation, result: .refused),
        AdminPromptRecord(feature: .keyboardCleaner, origin: .userAction, result: .succeeded),
    ])
}

@Test func theDisabledPrompterRefusesEvenAUserAction() {
    let prompter = DisabledAdminPrompter()
    #expect(prompter.runAsRoot("/usr/bin/true", feature: .sleepSetting, origin: .userAction) == .refused)
}

@Test func disablingPrivilegedPromptsReadsTheEnvironmentAndDefaults() throws {
    let suite = "pervigil-admin-prompt-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(!DisabledAdminPrompter.isRequested(environment: [:], defaults: defaults))
    #expect(DisabledAdminPrompter.isRequested(environment: ["PERVIGIL_DISABLE_PRIVILEGED": "1"], defaults: defaults))
    #expect(!DisabledAdminPrompter.isRequested(environment: ["PERVIGIL_DISABLE_PRIVILEGED": "0"], defaults: defaults))
    defaults.set(true, forKey: "PervigilDisablePrivileged")
    #expect(DisabledAdminPrompter.isRequested(environment: [:], defaults: defaults))
}

// MARK: - Backends route through it

@Test func sleepSettingWriteIsRefusedForAutomation() {
    let osascript = OsascriptRecorder()
    let control = PMSetSleepControl(prompter: OsascriptAdminPrompter(runner: osascript.runner))
    #expect(control.setSleepDisabled(false, origin: .automation) == .needsAuthorization)
    #expect(osascript.launches == 0)
    #expect(control.setSleepDisabled(false, origin: .userAction) == .applied)
    #expect(osascript.scripts.first?.contains("/usr/bin/pmset -a disablesleep 0") == true)
}

@Test func keyboardCleanerPromptKeepsTheMappingOneShellWord() {
    let osascript = OsascriptRecorder()
    let prompter = OsascriptAdminPrompter(runner: osascript.runner)
    #expect(OsascriptKeyboardRemapper.apply(.disabledKeyboard, prompter: prompter, origin: .userAction) == .applied)
    let command = OsascriptKeyboardRemapper.command(for: .disabledKeyboard)
    #expect(command.hasPrefix("/usr/bin/hidutil property --set '"))
    #expect(command.hasSuffix("'"))
    #expect(osascript.scripts.first?.contains(OsascriptAdminPrompter.appleScriptEscaped(command)) == true)
    // A refused prompt degrades to the overlay, never a second dialog.
    #expect(OsascriptKeyboardRemapper.apply(
        .disabledKeyboard, prompter: DisabledAdminPrompter(), origin: .userAction) == .overlayOnly)
}

// MARK: - Regression: no unattended prompt without the helper

/// Runs the closed-display automation the way the app host does, against the
/// real osascript-backed seams (osascript itself recorded), for one app
/// launch. A foreign hold is on the whole time, so the clear path is
/// exercised too.
@MainActor
private func runClosedLidLaunch(
    settings: PervigilSettings,
    sessions: [Bool],
    osascript: OsascriptRecorder,
    userPrimes: Bool = false
) async -> (actions: [ClosedDisplayCoordinator.Action], primeResult: SleepSettingResult?) {
    let prompter = OsascriptAdminPrompter(runner: osascript.runner)
    let control = PMSetSleepControl(prompter: prompter)
    let auto = ClosedDisplayAutoController(
        launcher: OsascriptSleepWatchdog(flagURL: tempFlagURL("sleep.flag"), ownerPID: 1, prompter: prompter),
        appPID: 1
    )
    auto.onlyWhileBrewing = settings.closedDisplayOnlyWhileBrewing
    await auto.cleanupAtLaunch()
    let coordinator = ClosedDisplayCoordinator(pollInterval: 2)
    var primeResult: SleepSettingResult?
    if userPrimes { primeResult = await auto.prime() }

    func conditions(brewing: Bool) -> ClosedDisplayCoordinator.Conditions {
        .init(
            onlyWhileBrewing: settings.closedDisplayOnlyWhileBrewing,
            brewing: brewing,
            helperInstalled: false,
            automationHolding: auto.isHolding,
            automationAuthorized: auto.isAuthorized,
            automationFailed: auto.lastError != nil,
            settingIsOn: true,
            settingIsBusy: false,
            fallbackDeclined: settings.closedLidFallbackDeclined
        )
    }
    var seen: [ClosedDisplayCoordinator.Action] = []
    func perform(_ action: ClosedDisplayCoordinator.Action, brewing: Bool) async {
        seen.append(action)
        switch action {
        case .runAutoTick(let brewing):
            await auto.autoTick(brewing: brewing)
        case .refreshThenEnforce:
            let token = coordinator.beginRefresh()
            coordinator.endRefresh(token, settingIsOn: true)
            if let next = coordinator.enforce(conditions(brewing: brewing)) {
                await perform(next, brewing: brewing)
            }
        case .clearForeignHold(let origin):
            _ = control.setSleepDisabled(false, origin: origin)
        case .surfaceNeedsAuthorization, .verifyHelper:
            break
        }
    }
    for brewing in sessions {
        for action in coordinator.tick(conditions(brewing: brewing)) {
            await perform(action, brewing: brewing)
        }
    }
    return (seen, primeResult)
}

/// Five seconds of session, five idle, twice.
private let twoSessions = Array(repeating: true, count: 5) + Array(repeating: false, count: 5)
    + Array(repeating: true, count: 5) + Array(repeating: false, count: 5)

@MainActor
@Test func noUnattendedPromptWithoutHelper() async throws {
    // The reported bug: no helper, "Only while awake" on, a session running
    // at launch. Relaunch three times (new instances, same persisted
    // settings): osascript must never run, and each launch says once that
    // the feature needs the helper.
    let osascript = OsascriptRecorder()
    var settings = PervigilSettings.default
    settings.closedDisplayOnlyWhileBrewing = true
    for _ in 0..<3 {
        let persisted = try JSONDecoder().decode(PervigilSettings.self, from: JSONEncoder().encode(settings))
        let launch = await runClosedLidLaunch(settings: persisted, sessions: twoSessions, osascript: osascript)
        #expect(launch.actions.filter { $0 == .surfaceNeedsAuthorization }.count == 1)
    }
    #expect(osascript.launches == 0)
}

@MainActor
@Test func userActionMayPromptOnce() async {
    // A click on "Allow once" asks exactly once; the rest of the run's
    // sessions follow prompt-free.
    let osascript = OsascriptRecorder()
    var settings = PervigilSettings.default
    settings.closedDisplayOnlyWhileBrewing = true
    let launch = await runClosedLidLaunch(settings: settings, sessions: twoSessions, osascript: osascript, userPrimes: true)
    #expect(launch.primeResult == .applied)
    #expect(osascript.launches == 1)
    #expect(osascript.scripts.first?.contains(AdminPromptFeature.sleepWatchdog.reason) == true)
    #expect(!launch.actions.contains(.surfaceNeedsAuthorization))
}

@MainActor
@Test func cancelPersistsAcrossSessionsAndLaunches() async throws {
    // Launch 1: the user cancels Allow once, and the host persists the
    // decline. Later launches stay silent: no prompt and no notice.
    let osascript = OsascriptRecorder()
    osascript.status = 1
    osascript.stderr = "execution error: User canceled. (-128)"
    var settings = PervigilSettings.default
    settings.closedDisplayOnlyWhileBrewing = true
    let first = await runClosedLidLaunch(settings: settings, sessions: twoSessions, osascript: osascript, userPrimes: true)
    #expect(first.primeResult == .cancelled)
    #expect(osascript.launches == 1)
    settings.closedLidFallbackDeclined = true // what the host does on .cancelled

    for _ in 0..<2 {
        let persisted = try JSONDecoder().decode(PervigilSettings.self, from: JSONEncoder().encode(settings))
        let launch = await runClosedLidLaunch(settings: persisted, sessions: twoSessions, osascript: osascript)
        #expect(!launch.actions.contains(.surfaceNeedsAuthorization))
    }
    #expect(osascript.launches == 1)
}

@MainActor
@Test func awdlAutoPauseNeverPromptsWithoutHelper() async {
    let osascript = OsascriptRecorder()
    let prompter = OsascriptAdminPrompter(runner: osascript.runner)
    for _ in 0..<3 { // three launches
        let controller = AWDLWatchdogController(
            launcher: OsascriptAWDLWatchdog(flagURL: tempFlagURL("awdl.flag"), ownerPID: 1, prompter: prompter),
            appPID: 1
        )
        controller.autoWithGaming = true
        for gaming in [true, true, true, false, true, true] {
            await controller.autoTick(gamingActive: gaming)
        }
        #expect(controller.needsAuthorization)
        #expect(!controller.isRunning)
    }
    #expect(osascript.launches == 0)

    // The manual switch in the Gaming & Streaming window is a user action.
    let manual = AWDLWatchdogController(
        launcher: OsascriptAWDLWatchdog(flagURL: tempFlagURL("awdl.flag"), ownerPID: 1, prompter: prompter),
        appPID: 1
    )
    #expect(await manual.start(origin: .userAction) == .started)
    #expect(osascript.launches == 1)
    #expect(osascript.scripts.first?.contains(AdminPromptFeature.awdlPause.reason) == true)
    await manual.stop()
}
