import Foundation

/// Who is asking for an administrator password.
///
/// The rule this type exists to enforce: background automation never shows an
/// administrator prompt. Only a direct user action may, and only through
/// ``AdminPrompting``. Without the helper daemon, automation reports a "needs
/// helper" state instead of asking.
public enum PromptOrigin: String, Equatable, Sendable {
    /// A click, a toggle, a menu choice: the user is at the keyboard and knows
    /// why a dialog just appeared.
    case userAction
    /// A tick, a trigger, a session edge: nobody may be at the keyboard, and a
    /// dialog titled "osascript" out of nowhere reads like malware.
    case automation
}

/// The feature asking for root, so the dialog and the log can say what the
/// password is for.
public enum AdminPromptFeature: String, Equatable, Sendable, CaseIterable {
    /// The global `pmset disablesleep` switch (closed-display mode).
    case sleepSetting
    /// The root loop behind "Only while awake" closed-display mode.
    case sleepWatchdog
    /// The root loop that pauses AWDL.
    case awdlPause
    /// The keyboard remap behind Keyboard Cleaner.
    case keyboardCleaner

    /// The sentence macOS shows in the dialog (under the "osascript" title,
    /// which the system picks and the app can't change).
    public var reason: String {
        switch self {
        case .sleepSetting:
            return L("Pervigil needs your password to change the Mac's sleep setting.")
        case .sleepWatchdog:
            return L("Pervigil needs your password to keep the Mac awake with the lid closed during sessions.")
        case .awdlPause:
            return L("Pervigil needs your password to pause AWDL (AirDrop, Handoff and Continuity).")
        case .keyboardCleaner:
            return L("Pervigil needs your password to lock or unlock the keyboard for cleaning.")
        }
    }
}

/// Outcome of one ``AdminPrompting/runAsRoot(_:feature:origin:)`` call.
public enum AdminPromptResult: Equatable, Sendable {
    /// The command ran as root and exited 0.
    case succeeded
    /// The user dismissed the dialog (or mistyped until macOS gave up, which
    /// osascript reports the same way).
    case cancelled
    /// No dialog was shown: the origin may not prompt (automation), or
    /// privileged prompts are disabled for this process.
    case refused
    /// osascript itself couldn't be launched.
    case launchFailed
    /// The command ran and failed; stderr, trimmed (may be empty).
    case failed(String)
}

/// Which origins may show a dialog.
public enum AdminPromptPolicy {
    /// Automation never may. A missing helper is surfaced as a state the user
    /// can act on, never as a password dialog nobody asked for.
    public static func allows(_ origin: PromptOrigin) -> Bool {
        origin == .userAction
    }
}

/// One attempted prompt, for the host's log.
public struct AdminPromptRecord: Equatable, Sendable {
    public var feature: AdminPromptFeature
    public var origin: PromptOrigin
    public var result: AdminPromptResult

    public init(feature: AdminPromptFeature, origin: PromptOrigin, result: AdminPromptResult) {
        self.feature = feature
        self.origin = origin
        self.result = result
    }
}

/// The one place in the app that may show an administrator prompt. Every
/// fallback path that needs root without the helper daemon goes through this,
/// so the "automation never prompts" rule lives in one implementation (and
/// `scripts/check-admin-prompts.sh` fails CI if a new call site bypasses it).
///
/// Blocking: a call that shows the dialog waits for the user to answer it, so
/// callers run it off the main actor.
public protocol AdminPrompting: AnyObject, Sendable {
    func runAsRoot(_ shellCommand: String, feature: AdminPromptFeature, origin: PromptOrigin) -> AdminPromptResult
}

/// Real prompter over `osascript`'s `do shell script ... with administrator
/// privileges`, which shows the standard macOS authorization dialog. The
/// dialog carries the feature's ``AdminPromptFeature/reason`` so it says who
/// is asking.
public final class OsascriptAdminPrompter: AdminPrompting, @unchecked Sendable {
    public typealias Runner = @Sendable (_ path: String, _ arguments: [String]) -> (status: Int32, stderr: String)?

    private let runner: Runner
    private let observer: (@Sendable (AdminPromptRecord) -> Void)?

    /// `observer` sees every attempt, refused ones included, so the host can
    /// log what asked and when.
    public init(
        runner: @escaping Runner = OsascriptAdminPrompter.run,
        observer: (@Sendable (AdminPromptRecord) -> Void)? = nil
    ) {
        self.runner = runner
        self.observer = observer
    }

    public func runAsRoot(_ shellCommand: String, feature: AdminPromptFeature, origin: PromptOrigin) -> AdminPromptResult {
        let result: AdminPromptResult
        if AdminPromptPolicy.allows(origin) {
            let script = Self.script(for: shellCommand, reason: feature.reason)
            if let output = runner("/usr/bin/osascript", ["-e", script]) {
                result = Self.outcome(status: output.status, stderr: output.stderr)
            } else {
                result = .launchFailed
            }
        } else {
            result = .refused
        }
        observer?(AdminPromptRecord(feature: feature, origin: origin, result: result))
        return result
    }

    /// The AppleScript for one root command. Both the command and the reason
    /// are embedded as escaped AppleScript string literals.
    public static func script(for shellCommand: String, reason: String) -> String {
        "do shell script \"\(appleScriptEscaped(shellCommand))\" "
            + "with prompt \"\(appleScriptEscaped(reason))\" with administrator privileges"
    }

    /// Escape text for embedding in an AppleScript string literal.
    public static func appleScriptEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Map osascript's exit status and stderr onto a result. osascript
    /// reports a cancelled dialog as error -128.
    public static func outcome(status: Int32, stderr: String) -> AdminPromptResult {
        if status == 0 { return .succeeded }
        if stderr.contains("-128") || stderr.localizedCaseInsensitiveContains("cancel") {
            return .cancelled
        }
        return .failed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Run a command and return its exit status plus stderr, or `nil` if it
    /// couldn't be launched.
    public static func run(_ path: String, _ arguments: [String]) -> (status: Int32, stderr: String)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        let errPipe = Pipe()
        process.standardError = errPipe
        do {
            try process.run()
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch {
            return nil
        }
    }
}

/// Prompter that never shows a dialog, for dev and QA runs that must not touch
/// root paths (the `PervigilDisablePrivileged` default or the
/// `PERVIGIL_DISABLE_PRIVILEGED` environment variable). Every call is refused.
public final class DisabledAdminPrompter: AdminPrompting, @unchecked Sendable {
    private let observer: (@Sendable (AdminPromptRecord) -> Void)?

    public init(observer: (@Sendable (AdminPromptRecord) -> Void)? = nil) {
        self.observer = observer
    }

    public func runAsRoot(_ shellCommand: String, feature: AdminPromptFeature, origin: PromptOrigin) -> AdminPromptResult {
        observer?(AdminPromptRecord(feature: feature, origin: origin, result: .refused))
        return .refused
    }

    /// Whether this process asked for privileged prompts to be disabled.
    public static func isRequested(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> Bool {
        if let value = environment["PERVIGIL_DISABLE_PRIVILEGED"],
           ["1", "true", "yes"].contains(value.lowercased()) {
            return true
        }
        return defaults.bool(forKey: "PervigilDisablePrivileged")
    }
}
