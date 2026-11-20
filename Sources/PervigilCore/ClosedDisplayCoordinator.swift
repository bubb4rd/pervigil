import Foundation

/// Sequences closed-display mode's "only while brewing" automation: what to do
/// on each tick, and the latches that keep those decisions from repeating.
///
/// Host-driven like ``SessionController``. It owns no timer, spawns no task and
/// never touches the system: the host samples a ``Conditions`` snapshot, hands
/// it in, and runs the ``Action``s that come back. That keeps the delicate part
/// testable without a running app, since the bugs here are all in the
/// sequencing: edge detection, the once-per-run "needs helper" notice, and the
/// re-read latch that stops enforcement from acting on a stale setting.
///
/// Nothing this type asks for may show a password dialog on its own: without
/// the helper, automation reports that it needs one (see
/// ``AdminPromptPolicy``). Only ``enforce(_:allowPrompt:)`` called from a user
/// action may lead to a prompt.
///
/// The decision of whether a foreign hold should be cleared at all stays in
/// ``ClosedDisplayAuthority``; this type decides *when* to ask, and remembers
/// the answer.
@MainActor
public final class ClosedDisplayCoordinator {
    /// Everything the decisions read, sampled once per call so no decision
    /// races a value changing underneath it.
    public struct Conditions: Equatable, Sendable {
        /// Whether the "only while brewing" feature is on.
        public var onlyWhileBrewing: Bool
        /// Whether a keep-awake session is running.
        public var brewing: Bool
        /// With the root helper installed every flip is silent; without it a
        /// flip needs an administrator password.
        public var helperInstalled: Bool
        /// Whether the automation currently holds the setting itself.
        public var automationHolding: Bool
        /// Whether the fallback's authorization was already granted this run.
        public var automationAuthorized: Bool
        /// Whether the automation's last engage attempt failed.
        public var automationFailed: Bool
        /// Last read of the system setting: `true` on, `false` off, `nil` when
        /// never read or unreadable.
        public var settingIsOn: Bool?
        /// Whether an administrator prompt for the setting is already on screen.
        public var settingIsBusy: Bool
        /// Whether the user cancelled a fallback password prompt and hasn't
        /// acted on the feature since (persisted across launches). Silences
        /// the "needs helper" notice; the menu still shows the state.
        public var fallbackDeclined: Bool

        public init(
            onlyWhileBrewing: Bool,
            brewing: Bool,
            helperInstalled: Bool,
            automationHolding: Bool,
            automationAuthorized: Bool,
            automationFailed: Bool,
            settingIsOn: Bool?,
            settingIsBusy: Bool,
            fallbackDeclined: Bool = false
        ) {
            self.onlyWhileBrewing = onlyWhileBrewing
            self.brewing = brewing
            self.helperInstalled = helperInstalled
            self.automationHolding = automationHolding
            self.automationAuthorized = automationAuthorized
            self.automationFailed = automationFailed
            self.settingIsOn = settingIsOn
            self.settingIsBusy = settingIsBusy
            self.fallbackDeclined = fallbackDeclined
        }
    }

    /// A side effect for the host to run, in the order returned.
    public enum Action: Equatable, Sendable {
        /// Session start with no authorization and no helper: the engage will
        /// stand down rather than prompt, so tell the user (quietly, once per
        /// app run) that the feature needs the helper or an "Allow once".
        case surfaceNeedsAuthorization
        /// An engage failed with the helper installed, which should not happen:
        /// suspect a stale daemon registration and check it.
        case verifyHelper
        /// Pulse the automation with the session's live state.
        case runAutoTick(brewing: Bool)
        /// Re-read the system setting, then enforce on what comes back. `delay`
        /// is in seconds and non-nil only where the helper needs a cycle to
        /// apply a change first.
        case refreshThenEnforce(delay: Int?)
        /// Clear a hold taken outside the automation. `origin` is what the
        /// write may do: a `.userAction` clear may prompt without the helper,
        /// an `.automation` one only happens with the helper installed.
        case clearForeignHold(origin: PromptOrigin)
    }

    /// Seconds to wait before mirroring an engage or release into the setting's
    /// live state, so the helper has had a cycle to apply it.
    public static let mirrorDelay = 3

    /// Ticks between unattended re-reads while the automation owns the setting.
    /// Each read shells out to `pmset -g`, so this stays slow: it is there to
    /// notice a change made behind the app's back (`pmset` by hand, another
    /// tool), not to drive the UI.
    nonisolated public static let defaultPollInterval = 30

    private let pollInterval: Int
    private var sawBrewing = false
    private var sawHolding = false
    private var sawAutomationFailure = false
    /// Whether a foreign hold was already cleared, so a write that doesn't take
    /// (a failing helper, a cancelled prompt) isn't retried every second.
    private var clearedForeignHold = false
    /// Whether the "needs helper" notice was already sent this app run.
    private var surfacedNeedsAuthorization = false
    /// Whether a re-read is still in flight. The setting's state is a cache, and
    /// acting on it between an engage/release and its re-read would enforce
    /// against a stale value (and without the helper, ask the user for a
    /// password to change nothing).
    private var refreshPending = false
    private var refreshGeneration = 0
    private var pollTicks = 0

    public init(pollInterval: Int = ClosedDisplayCoordinator.defaultPollInterval) {
        self.pollInterval = pollInterval
    }

    /// Once-a-second pulse. Returns the actions to run, in order.
    ///
    /// The host must run them before the next ``tick(_:)``: a
    /// ``Action/refreshThenEnforce(delay:)`` only latches enforcement out once
    /// the host claims it with ``beginRefresh()``, so a tick that drops the
    /// action, or defers it past another tick, would leave enforcement free to
    /// act on the reading that refresh is about to replace.
    public func tick(_ conditions: Conditions) -> [Action] {
        guard conditions.onlyWhileBrewing else { return [] }
        var actions: [Action] = []
        let brewing = conditions.brewing
        if brewing, !sawBrewing, !surfacedNeedsAuthorization, !conditions.automationAuthorized,
           !conditions.helperInstalled, !conditions.fallbackDeclined {
            surfacedNeedsAuthorization = true
            actions.append(.surfaceNeedsAuthorization)
        }
        sawBrewing = brewing
        // A session hands the setting back to the automation: let the next idle
        // stretch clear a foreign hold again (the release may restore one).
        if brewing { clearedForeignHold = false }
        if conditions.automationFailed, !sawAutomationFailure, conditions.helperInstalled {
            actions.append(.verifyHelper)
        }
        sawAutomationFailure = conditions.automationFailed
        actions.append(.runAutoTick(brewing: brewing))
        // Mirror an engage or release into the setting's live state. Ticks in
        // between stay out of the way, since the cached state is the pre-change
        // one until that read lands.
        if conditions.automationHolding != sawHolding {
            sawHolding = conditions.automationHolding
            pollTicks = 0
            actions.append(.refreshThenEnforce(delay: Self.mirrorDelay))
            return actions
        }
        // Nothing to mirror, so the cached setting only goes stale from the
        // outside. Re-read it now and then, and enforce on what comes back.
        pollTicks += 1
        if !brewing, pollTicks >= pollInterval, !conditions.settingIsBusy, !refreshPending {
            pollTicks = 0
            actions.append(.refreshThenEnforce(delay: nil))
        } else if let action = enforce(conditions) {
            actions.append(action)
        }
        return actions
    }

    /// Enforce the feature's authority: with it on, idle means the sleep setting
    /// is off, even when the hold was taken outside the automation.
    ///
    /// `allowPrompt` marks the paths where the user is at the keyboard,
    /// having just acted on the feature: only those may clear without the
    /// helper, since that clear needs a password prompt. Unattended, a foreign
    /// hold without the helper is left alone.
    public func enforce(_ conditions: Conditions, allowPrompt: Bool = false) -> Action? {
        guard !conditions.settingIsBusy, !clearedForeignHold else { return nil }
        // Never act on a value a pending re-read is about to replace.
        guard !refreshPending else { return nil }
        let needsPassword = !conditions.helperInstalled
        guard ClosedDisplayAuthority.shouldClearForeignHold(
            onlyWhileBrewing: conditions.onlyWhileBrewing,
            brewing: conditions.brewing,
            automationHolding: conditions.automationHolding,
            settingIsOn: conditions.settingIsOn == true,
            canApply: !needsPassword || allowPrompt
        ) else { return nil }
        clearedForeignHold = true
        return .clearForeignHold(origin: allowPrompt ? .userAction : .automation)
    }

    /// Claim the next re-read, latching enforcement out until it lands.
    public func beginRefresh() -> Int {
        refreshGeneration += 1
        refreshPending = true
        return refreshGeneration
    }

    /// Whether `token` is still the newest claim. A superseded read must not
    /// clear the latch or enforce on a value a newer one is about to replace.
    public func refreshIsCurrent(_ token: Int) -> Bool { token == refreshGeneration }

    /// Land a completed re-read. Returns false when superseded, in which case
    /// the latch stays in place for the newer claim.
    @discardableResult
    public func endRefresh(_ token: Int, settingIsOn: Bool?) -> Bool {
        guard refreshIsCurrent(token) else { return false }
        refreshPending = false
        // A confirmed-off setting means an earlier clear took: arm again, so a
        // hold taken later in this idle stretch is still caught.
        if settingIsOn == false { clearedForeignHold = false }
        return true
    }

    /// Arm the foreign-hold clear again, for the user toggling the feature.
    public func rearmForeignHoldClear() { clearedForeignHold = false }
}
