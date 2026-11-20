import Foundation
import AppKit
import PervigilCore

/// Which duration chip started the running manual session. "Until…" and
/// "Custom…" produce plain timed sessions, so the panel remembers the chip to
/// keep it selected.
enum PanelDurationChoice: Equatable {
    case noLimit, minutes(Int), until, custom
}

/// The redesigned panel's bridge to the session: builds the Core
/// ``PanelInput`` from live state and carries out the panel's actions.
extension AppModel {
    /// Triggers or automation leases, rather than the user, hold the Mac.
    var heldByAutomation: Bool {
        session.isActive && ((triggersEnabled && !triggersPaused) || session.isLeaseHeld)
    }

    /// The status card's content for this tick.
    func panelStatus(now: Date = Date()) -> PanelStatus {
        let power = powerReading
        let options = session.options
        let states = ruleStates() ?? []
        let reasons = PanelStatus.reasons(states: states, leases: session.liveLeases, context: panelSourceContext(states: states))
        let input = PanelInput(
            now: now,
            isActive: session.isActive,
            pausedByBattery: session.pausedByBattery,
            pausedByThermal: session.pausedByThermal,
            elapsed: menuPanel.elapsed > 0 ? menuPanel.elapsed : session.elapsed,
            remaining: session.remaining,
            totalDuration: session.remaining == nil ? nil : session.mode.duration,
            triggersEnabled: triggersEnabled,
            triggersPaused: triggersPaused,
            ruleCount: rules.count,
            leaseHeld: session.isLeaseHeld,
            reasons: reasons,
            hasBattery: machineHasBattery,
            batteryPercent: power.percentage,
            onBattery: power.provider == .battery,
            batteryGuardOn: batteryAutoPauseEnabled,
            batteryThreshold: pauseBelowBatteryPercent,
            lidOn: closedDisplayEnabled || closedDisplayOnlyWhileBrewing,
            lidOnlyWhileAwake: closedDisplayOnlyWhileBrewing,
            lidNeedsHelper: closedLidNeedsHelper,
            preventDisplaySleep: options.preventDisplaySleep,
            dimsWhenIdle: options.dimDisplayAfter != nil,
            stayActiveMethod: simulateUserActivity ? activitySimulationMethod.shortLabel : nil)
        return PanelStatus.make(input, formatDuration: { MenuBarLabel.format($0) })
    }

    /// The app on a call and the game in front, when a rule about them is
    /// met. Resolved at most every two seconds: the mic capturer list walks
    /// CoreAudio's process objects.
    func panelSourceContext(states: [RuleState]) -> PanelSourceContext {
        if let cached = panelContextCache, Date().timeIntervalSince(cached.at) < 2 { return cached.context }
        var context = PanelSourceContext()
        let met = states.filter { $0.satisfied || $0.inGrace }.map(\.rule)
        if met.contains(where: { if case .micInUse = $0 { return true }; return $0 == .mediaInUse(.microphone) }),
           let capturer = CoreMediaActivityMonitor.currentMicCapturers().first {
            let app = Self.resolveCapturingApp(pid: capturer.pid, rawBundleID: capturer.bundleID)
            context.micApp = .app(bundleID: app.bundleID, bundlePath: nil, pid: capturer.pid)
        }
        if met.contains(.gaming), let front = NSWorkspace.shared.frontmostApplication {
            context.gameApp = .app(bundleID: front.bundleIdentifier, bundlePath: front.bundleURL?.path,
                                   pid: front.processIdentifier)
        }
        panelContextCache = (Date(), context)
        return context
    }

    /// Starts, or re-times, a manual session from a duration chip.
    func startPanelSession(_ mode: SessionMode, choice: PanelDurationChoice) {
        panelDurationChoice = choice
        startManualOverride(mode: mode)
    }

    /// Starts a session until a wall-clock time from the inline editor.
    func startPanelSession(untilHour hour: Int, minute: Int) {
        panelDurationChoice = .until
        startUntil(hour: hour, minute: minute)
    }

    /// The status card's "Keep awake": a manual session with the last used
    /// duration, taking control from the triggers as the switch always has.
    func keepAwakeFromPanel() {
        guard !session.isActive else { return }
        if panelDurationChoice == nil { panelDurationChoice = Self.choice(for: defaultMode) }
        toggleManual()
    }

    /// Carries out the stop control, whatever is holding the Mac.
    func performPanelStop(_ action: PanelStatus.StopAction) {
        switch action {
        case .stopSession:
            if session.isActive { toggleManual() }
        case .setTriggersAside:
            pauseTriggers()
        case .endLeases:
            endAutomationLeases()
        case .endPausedSession:
            // The pause has already stopped the session; this drops the
            // remembered intent so it does not come back when the pause lifts.
            if triggersEnabled && !triggersPaused {
                pauseTriggers()
            } else {
                session.stop()
            }
        }
        panelDurationChoice = nil
    }

    static func choice(for mode: SessionMode) -> PanelDurationChoice {
        guard let duration = mode.duration else { return .noLimit }
        let minutes = Int((duration / 60).rounded())
        return [15, 60, 240].contains(minutes) ? .minutes(minutes) : .custom
    }
}

extension ActivitySimulationMethod {
    /// The method's name in Preferences, shared with the panel's tile.
    var menuLabel: String {
        switch self {
        case .powerWarp: return L("Power / cursor warp")
        case .f15: return L("F15 key every 60 s")
        case .shift: return L("Shift every 60 s")
        case .specifiedKey: return L("Specified key")
        case .mouseMove: return L("Mouse move")
        }
    }

    /// A tile-width name for the Stay Active tile.
    var shortLabel: String {
        switch self {
        case .powerWarp: return L("Cursor warp")
        case .f15: return L("F15 key")
        case .shift: return L("Shift key")
        case .specifiedKey: return L("Specified key")
        case .mouseMove: return L("Mouse move")
        }
    }
}
