import Foundation

/// Where a reason or a trigger row comes from, named but not drawn. Core stays
/// image-free; the app turns a source into the icon macOS itself draws for it
/// (`AppIconProvider`), so Pervigil never bundles other companies' logos.
public enum TriggerSource: Hashable, Sendable {
    /// An installed or running app. Any of the three may be known; the
    /// resolver tries the running process, then the bundle id, then the path.
    case app(bundleID: String?, bundlePath: String?, pid: Int32?)
    /// An AI agent by its detection id ("claude", "codex", ...), drawn with
    /// the agent's own mark.
    case agent(String)
    /// A file or folder, drawn with the system icon for its type.
    case file(URL)
    /// An SF Symbol name, for everything without an app behind it.
    case symbol(String)
}

/// One thing holding the Mac awake right now, for the status card's icon
/// stack. The label is the full sentence a tooltip and VoiceOver read.
public struct PanelReason: Hashable, Sendable, Identifiable {
    public enum Kind: Hashable, Sendable {
        case agent, call, download, game, lease, grace, other
    }
    public var kind: Kind
    public var source: TriggerSource
    public var label: String
    /// Seconds left in a grace window, for the amber countdown chip.
    public var countdown: TimeInterval?
    public var id: String

    public init(kind: Kind, source: TriggerSource, label: String, countdown: TimeInterval? = nil, id: String) {
        self.kind = kind
        self.source = source
        self.label = label
        self.countdown = countdown
        self.id = id
    }
}

/// Identities the host resolved for the current tick, so reasons and rows can
/// name the actual app (the one on the call, the game in front).
public struct PanelSourceContext: Equatable, Sendable {
    /// The app capturing the microphone, resolved to its top-level `.app`.
    public var micApp: TriggerSource?
    /// The frontmost game.
    public var gameApp: TriggerSource?

    public init(micApp: TriggerSource? = nil, gameApp: TriggerSource? = nil) {
        self.micApp = micApp
        self.gameApp = gameApp
    }
}

/// Agent ids to the names their makers use. Product names, never translated.
public enum AgentNames {
    /// The agent ids Pervigil detects and can draw a mark for.
    public static let known: Set<String> = [
        "claude", "codex", "cursor", "cursor-agent", "agy", "antigravity", "gemini", "grok", "omp",
        "hermes", "qwen", "devin", "kimi", "cline", "kilo", "opencode", "opencode2", "muse",
    ]

    public static func displayName(_ agent: String) -> String {
        switch agent.lowercased() {
        case "claude": return "Claude Code"
        case "codex": return "Codex"
        case "cursor", "cursor-agent": return "Cursor"
        case "agy", "antigravity": return "Antigravity"
        case "gemini": return "Gemini CLI"
        case "grok": return "Grok"
        case "omp": return "Oh My Pi"
        case "hermes": return "Hermes Agent"
        case "qwen": return "Qwen Code"
        case "devin": return "Devin"
        case "kimi": return "Kimi Code"
        case "cline": return "Cline"
        case "kilo": return "Kilo Code"
        case "opencode", "opencode2": return "opencode"
        case "muse": return "Muse"
        default: return agent.prefix(1).uppercased() + agent.dropFirst()
        }
    }
}

extension TriggerRule {
    /// The SF Symbol for a trigger row's category icon.
    public var symbolName: String {
        switch self {
        case .powerSource: return "bolt"
        case .externalDisplay: return "display"
        case .wifiSSID: return "wifi"
        case .app: return "app"
        case .process: return "terminal"
        case .timeWindow: return "clock"
        case .volumeMounted: return "externaldrive"
        case .cpuLoad: return "cpu"
        case .mediaInUse(let device): return device == .camera ? "video" : "mic"
        case .micInUse: return "mic"
        case .audioPlaying: return "speaker.wave.2"
        case .vpnConnected: return "lock.shield"
        case .bluetoothDevice: return "dot.radiowaves.left.and.right"
        case .calendarEvent: return "calendar"
        case .gaming, .controllerConnected: return "gamecontroller"
        case .throughput: return "arrow.up.arrow.down"
        case .downloadInFolder, .steamDownload: return "arrow.down.to.line"
        case .agentActivity: return "sparkle"
        }
    }
}

/// The status card's content: what the panel says, top to bottom, for one
/// tick. A pure function of ``PanelInput`` so every branch is unit-tested with
/// a fixed clock instead of living in a view.
/// What fills the big number's spot when there is no countdown: how long the
/// Mac has been held, or the grace window before it may sleep.
public enum PanelClock: Equatable, Sendable {
    /// Triggers or a lease have held the Mac this long.
    case heldFor(TimeInterval)
    /// A manual session with no time limit has run this long.
    case awakeFor(TimeInterval)
    /// Only a grace window is left; the Mac may sleep when it ends.
    case grace(TimeInterval)
}

public struct PanelStatus: Equatable, Sendable {
    public enum State: Equatable, Sendable { case awake, canSleep, paused }
    public enum Tone: Equatable, Sendable { case normal, warning }

    /// What the stop control does in this state, so its label and action
    /// always agree.
    public enum StopAction: Equatable, Sendable {
        /// End a manual session.
        case stopSession
        /// Triggers hold the Mac: set them aside (Manual), as today.
        case setTriggersAside
        /// Only automation leases hold the Mac: end them.
        case endLeases
        /// A safety pause is holding a session back: drop it for good.
        case endPausedSession
    }

    public var state: State
    public var tone: Tone
    public var title: String
    /// The line under the title. `nil` while reasons are shown as icons.
    public var subtitle: String?
    /// A quieter second line ("Plug in to keep going.").
    public var detail: String?
    /// Icons for whatever holds the Mac, in priority order.
    public var reasons: [PanelReason]
    /// Seconds left in a timed session, for the big countdown.
    public var countdown: TimeInterval?
    /// Share of a timed session still to run, 1 down to 0.
    public var progress: Double?
    /// `nil` while the Mac can sleep (the panel offers Keep awake instead).
    public var stop: StopAction?
    /// Whether the mark shows the filled inner triangle: a trigger or lease,
    /// not the user, is holding the Mac.
    public var heldByAutomation: Bool
    public var tiles: GuardTileValues
    /// The clock in the countdown's spot when there is no countdown.
    public var clock: PanelClock? = nil
}

/// The second line of each guard tile.
public struct GuardTileValues: Equatable, Sendable {
    public var lid: String
    /// The lid automation is on but can't act without the helper (or an
    /// "Allow once" this run), so the tile shows a lock instead of a state.
    public var lidNeedsHelper: Bool = false
    public var battery: String
    public var batteryWarning: Bool
    public var display: String
    public var stayActive: String
}

/// Everything ``PanelStatus/make(_:formatTime:formatDuration:)`` reads.
public struct PanelInput: Sendable {
    public var now: Date
    public var isActive: Bool
    public var pausedByBattery: Bool
    public var pausedByThermal: Bool
    /// Seconds a manual session has run, for "on for 6:00".
    public var elapsed: TimeInterval
    /// Seconds left in a timed manual session.
    public var remaining: TimeInterval?
    /// The timed session's full length, for the progress line.
    public var totalDuration: TimeInterval?
    public var triggersEnabled: Bool
    public var triggersPaused: Bool
    public var ruleCount: Int
    /// The session is sustained by automation leases alone.
    public var leaseHeld: Bool
    public var reasons: [PanelReason]
    public var hasBattery: Bool
    public var batteryPercent: Int?
    public var onBattery: Bool
    public var batteryGuardOn: Bool
    public var batteryThreshold: Int
    public var lidOn: Bool
    public var lidOnlyWhileAwake: Bool
    /// "Only while awake" is on, the helper isn't installed, and no user
    /// action has authorized the password fallback this run.
    public var lidNeedsHelper: Bool
    public var preventDisplaySleep: Bool
    public var dimsWhenIdle: Bool
    /// The Stay Active method's short name when on, `nil` when off.
    public var stayActiveMethod: String?

    public init(
        now: Date, isActive: Bool, pausedByBattery: Bool = false, pausedByThermal: Bool = false,
        elapsed: TimeInterval = 0, remaining: TimeInterval? = nil, totalDuration: TimeInterval? = nil,
        triggersEnabled: Bool = false, triggersPaused: Bool = false, ruleCount: Int = 0,
        leaseHeld: Bool = false, reasons: [PanelReason] = [],
        hasBattery: Bool = true, batteryPercent: Int? = nil, onBattery: Bool = false,
        batteryGuardOn: Bool = false, batteryThreshold: Int = 20,
        lidOn: Bool = false, lidOnlyWhileAwake: Bool = false, lidNeedsHelper: Bool = false,
        preventDisplaySleep: Bool = false, dimsWhenIdle: Bool = false, stayActiveMethod: String? = nil
    ) {
        self.now = now
        self.isActive = isActive
        self.pausedByBattery = pausedByBattery
        self.pausedByThermal = pausedByThermal
        self.elapsed = elapsed
        self.remaining = remaining
        self.totalDuration = totalDuration
        self.triggersEnabled = triggersEnabled
        self.triggersPaused = triggersPaused
        self.ruleCount = ruleCount
        self.leaseHeld = leaseHeld
        self.reasons = reasons
        self.hasBattery = hasBattery
        self.batteryPercent = batteryPercent
        self.onBattery = onBattery
        self.batteryGuardOn = batteryGuardOn
        self.batteryThreshold = batteryThreshold
        self.lidOn = lidOn
        self.lidOnlyWhileAwake = lidOnlyWhileAwake
        self.lidNeedsHelper = lidNeedsHelper
        self.preventDisplaySleep = preventDisplaySleep
        self.dimsWhenIdle = dimsWhenIdle
        self.stayActiveMethod = stayActiveMethod
    }

    /// Triggers decide, rather than a manual session.
    var triggersControlling: Bool { triggersEnabled && !triggersPaused }
}

extension PanelStatus {
    /// How close to the battery guard's cutoff, in percentage points, before
    /// the panel warns that the Mac is about to be let sleep.
    public static let batteryWarningMargin = 5

    public static func make(
        _ input: PanelInput,
        calendar: Calendar = .current,
        formatTime: (Date) -> String = { $0.formatted(date: .omitted, time: .shortened) },
        formatDuration: (TimeInterval) -> String
    ) -> PanelStatus {
        let tiles = tileValues(input)
        let automation = input.isActive && (input.triggersControlling || input.leaseHeld)

        if input.pausedByBattery || input.pausedByThermal {
            let sub = input.pausedByBattery
                ? L("Battery below %d%%.", input.batteryThreshold)
                : L("Running hot, letting the Mac cool down")
            return PanelStatus(
                state: .paused, tone: .warning, title: L("Paused"), subtitle: sub,
                detail: input.pausedByBattery ? L("Plug in to resume.") : nil,
                reasons: [], countdown: nil, progress: nil, stop: .endPausedSession,
                heldByAutomation: false, tiles: tiles)
        }

        guard input.isActive else {
            let sub: String
            if input.triggersControlling && input.ruleCount > 0 {
                sub = input.ruleCount == 1 ? L("Watching 1 trigger") : L("Watching %d triggers", input.ruleCount)
            } else {
                sub = L("Press the mark or pick a duration")
            }
            return PanelStatus(
                state: .canSleep, tone: .normal, title: L("Can sleep"), subtitle: sub, detail: nil,
                reasons: [], countdown: nil, progress: nil, stop: nil,
                heldByAutomation: false, tiles: tiles)
        }

        var status = PanelStatus(
            state: .awake, tone: .normal, title: L("Awake"), subtitle: nil, detail: nil,
            reasons: [], countdown: nil, progress: nil, stop: .stopSession,
            heldByAutomation: automation, tiles: tiles)

        if automation {
            status.reasons = input.reasons
            status.stop = input.triggersControlling ? .setTriggersAside : .endLeases
            if input.reasons.isEmpty { status.subtitle = L("Held by your triggers") }
            // Only grace windows left: the big amber clock says when the Mac
            // may sleep, so the chip would repeat it. Otherwise show how long
            // the Mac has been held.
            let graceLeft = input.reasons.filter { $0.kind == .grace }.compactMap(\.countdown).max()
            if let graceLeft, input.reasons.allSatisfy({ $0.kind == .grace }) {
                status.clock = .grace(graceLeft)
                status.reasons = []
                status.subtitle = L("Agents finished")
            } else {
                status.clock = .heldFor(input.elapsed)
            }
        } else if let remaining = input.remaining {
            let end = input.now.addingTimeInterval(remaining)
            status.subtitle = calendar.isDate(end, inSameDayAs: input.now)
                ? L("Stops at %@", formatTime(end))
                : L("Stops at %@ tomorrow", formatTime(end))
            status.countdown = remaining
            if let total = input.totalDuration, total > 0 {
                status.progress = min(1, max(0, remaining / total))
            }
        } else {
            status.subtitle = L("No time limit")
            status.clock = .awakeFor(input.elapsed)
        }

        if tiles.batteryWarning, let percent = input.batteryPercent {
            status.tone = .warning
            status.subtitle = L("Battery %d%%. Sleeps at %d%%.", percent, input.batteryThreshold)
            status.detail = L("Plug in to keep going.")
            status.reasons = []
        } else if input.lidOn && (!input.lidOnlyWhileAwake || input.isActive) && !automation
                    && !(input.lidOnlyWhileAwake && input.lidNeedsHelper) {
            status.detail = L("Lid can close")
        }
        return status
    }

    static func tileValues(_ input: PanelInput) -> GuardTileValues {
        let lidNeedsHelper = input.lidOn && input.lidOnlyWhileAwake && input.lidNeedsHelper
        let lid = lidNeedsHelper
            ? L("Needs helper")
            : input.lidOn
            ? (input.lidOnlyWhileAwake ? L("During sessions") : L("Stays awake"))
            : L("Sleeps")
        var battery: String
        var warning = false
        if !input.hasBattery {
            battery = L("No battery")
        } else if !input.batteryGuardOn {
            battery = L("Off")
        } else if !input.onBattery {
            battery = L("Plugged in")
        } else if input.pausedByBattery, let percent = input.batteryPercent {
            battery = L("Paused, %d%%", percent)
            warning = true
        } else if let percent = input.batteryPercent {
            let margin = percent - input.batteryThreshold
            if input.isActive && (0...batteryWarningMargin).contains(margin) {
                battery = L("%d%% to go", margin)
                warning = true
            } else {
                battery = L("%d%%, sleeps at %d%%", percent, input.batteryThreshold)
            }
        } else {
            battery = L("Below %d%%", input.batteryThreshold)
        }
        let display = input.preventDisplaySleep
            ? (input.dimsWhenIdle ? L("On, dims when idle") : L("Stays on"))
            : L("Can sleep")
        return GuardTileValues(
            lid: lid, lidNeedsHelper: lidNeedsHelper, battery: battery, batteryWarning: warning,
            display: display, stayActive: input.stayActiveMethod ?? L("Off"))
    }
}

// MARK: - Reasons

extension PanelStatus {
    /// What holds the Mac right now, as icon-stack reasons: working agents
    /// first (they are why most people run Pervigil), then the other met
    /// triggers in rule order, then automation leases. An agent rule kept
    /// alive only by its grace window becomes one amber countdown.
    public static func reasons(
        states: [RuleState],
        leases: [LeaseSummary],
        context: PanelSourceContext = PanelSourceContext()
    ) -> [PanelReason] {
        var agents: [PanelReason] = []
        var others: [PanelReason] = []
        var seenAgents = Set<String>()
        for (index, state) in states.enumerated() where state.satisfied || state.inGrace {
            let id = "rule-\(index)"
            switch state.rule {
            case .agentActivity:
                let working = state.details.filter(\.active).compactMap(\.agent)
                for agent in working where seenAgents.insert(agent).inserted {
                    agents.append(PanelReason(
                        kind: .agent, source: .agent(agent),
                        label: L("%@ is working", AgentNames.displayName(agent)), id: "agent-\(agent)"))
                }
                if working.isEmpty {
                    others.append(PanelReason(
                        kind: .grace, source: .symbol("clock"),
                        label: L("Agents finished. Waiting before sleep."),
                        countdown: state.graceRemaining, id: id))
                }
            case .micInUse, .mediaInUse:
                let camera = state.rule == .mediaInUse(.camera)
                others.append(PanelReason(
                    kind: .call, source: context.micApp ?? .symbol(camera ? "video" : "mic"),
                    label: L("On a call"), countdown: state.inGrace ? state.graceRemaining : nil, id: id))
            case .downloadInFolder:
                others.append(PanelReason(
                    kind: .download, source: .symbol("arrow.down.to.line"),
                    label: state.rule.label, countdown: state.inGrace ? state.graceRemaining : nil, id: id))
            case .steamDownload:
                others.append(PanelReason(
                    kind: .download, source: .app(bundleID: "com.valvesoftware.steam", bundlePath: nil, pid: nil),
                    label: state.rule.label, countdown: state.inGrace ? state.graceRemaining : nil, id: id))
            case .gaming:
                others.append(PanelReason(
                    kind: .game, source: context.gameApp ?? .symbol("gamecontroller"),
                    label: L("Playing a game"), countdown: state.inGrace ? state.graceRemaining : nil, id: id))
            case .app(let rule):
                others.append(PanelReason(
                    kind: .other, source: .app(bundleID: rule.bundleID, bundlePath: rule.bundlePath, pid: nil),
                    label: state.rule.label, countdown: state.inGrace ? state.graceRemaining : nil, id: id))
            default:
                others.append(PanelReason(
                    kind: .other, source: .symbol(state.rule.symbolName),
                    label: state.rule.label, countdown: state.inGrace ? state.graceRemaining : nil, id: id))
            }
        }
        let leaseReasons = leases.map { lease in
            PanelReason(
                kind: .lease,
                source: AgentNames.known.contains(lease.tool.lowercased())
                    ? .agent(lease.tool.lowercased()) : .symbol("clock.badge.checkmark"),
                label: L("Lease: %@", lease.task), id: "lease-\(lease.id)")
        }
        return agents + others + leaseReasons
    }

    /// The source shown at the right of a trigger row, when the row has a
    /// concrete app or place behind it.
    public static func rowSource(for rule: TriggerRule, context: PanelSourceContext) -> TriggerSource? {
        switch rule {
        case .micInUse, .mediaInUse(.microphone): return context.micApp
        case .gaming: return context.gameApp
        case .app(let app): return .app(bundleID: app.bundleID, bundlePath: app.bundlePath, pid: nil)
        case .steamDownload: return .app(bundleID: "com.valvesoftware.steam", bundlePath: nil, pid: nil)
        case .downloadInFolder(let url): return .file(url)
        default: return nil
        }
    }
}
