import Foundation

/// Where the reminder notifications land on one timed session, for the
/// timeline preview in Settings ▸ Reminders. A pure function of the reminder
/// settings, so the preview and the notifier can never disagree about when
/// something fires.
public struct ReminderTimeline: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// "Pervigil is still keeping your Mac awake".
        case reminder
        /// "Pervigil stops soon", before a timed session ends.
        case endingSoon
        /// The session ran out on its own.
        case ended
    }

    public struct Marker: Equatable, Sendable {
        public var kind: Kind
        /// Seconds after the session started.
        public var offset: TimeInterval
    }

    /// The session length the timeline is drawn for.
    public var length: TimeInterval
    /// In time order: every reminder before the end, the warning, and the end
    /// itself, each only when that notification is on.
    public var markers: [Marker]

    /// More reminders than this on one session are dropped: a 15 minute repeat
    /// over 8 hours is 31 bells, which no timeline can show.
    public static let maxReminders = 32

    public static func make(
        length: TimeInterval,
        reminderEnabled: Bool,
        reminderAfter: TimeInterval,
        reminderRepeats: Bool,
        endingSoonEnabled: Bool,
        endingSoonNotice: TimeInterval,
        notifyOnEnd: Bool
    ) -> ReminderTimeline {
        var markers: [Marker] = []
        if reminderEnabled, reminderAfter > 0 {
            var at = reminderAfter
            while at < length, markers.count < maxReminders {
                markers.append(Marker(kind: .reminder, offset: at))
                guard reminderRepeats else { break }
                at += reminderAfter
            }
        }
        // The warning only exists when it lands inside the session.
        if endingSoonEnabled, endingSoonNotice > 0, endingSoonNotice < length {
            markers.append(Marker(kind: .endingSoon, offset: length - endingSoonNotice))
        }
        if notifyOnEnd {
            markers.append(Marker(kind: .ended, offset: length))
        }
        markers.sort { $0.offset < $1.offset }
        return ReminderTimeline(length: length, markers: markers)
    }

    /// The first marker of a kind, for the notification preview.
    public func first(_ kind: Kind) -> Marker? {
        markers.first { $0.kind == kind }
    }
}
