import Foundation

/// The menu panel's sections, top to bottom in the standard layout. Customize
/// Menu shows, hides, and reorders these as whole blocks: the redesigned panel
/// merges controls that used to be separate rows (the manual toggle, the
/// duration menu, and the quick-stop buttons are one chip grid now), so a
/// row-level layout no longer maps onto it.
public enum PanelSection: String, CaseIterable, Codable, Identifiable, Sendable {
    /// The mark, the state, the reason, the countdown, and stop. Always first
    /// and always shown: it is the panel's answer to "is the Mac awake, why,
    /// and until when".
    case status
    /// Automatic or Manual, and the duration chips.
    case session
    /// The trigger list, agent rows, and automation leases.
    case triggers
    /// The Closed Lid, Battery Guard, Display, and Stay Active tiles.
    case guards
    /// Preferences, the compact switch, and the More menu.
    case footer

    public var id: String { rawValue }

    /// The status section can be neither hidden nor moved.
    public var isPinned: Bool { self == .status }
}

/// Which panel sections show, and in what order. Lives inside ``MenuLayout``
/// (see ``MenuLayout/panel``), so it rides the existing opt-in customization
/// flag and settings transfer.
public struct PanelLayout: Codable, Equatable, Sendable {
    /// Every section in display order. ``normalized()`` keeps it complete,
    /// free of duplicates, and with ``PanelSection/status`` first.
    public var order: [PanelSection]
    /// Sections the user turned off. Never contains a pinned section.
    public var hidden: Set<PanelSection>

    public init(order: [PanelSection] = PanelSection.allCases, hidden: Set<PanelSection> = []) {
        self.order = order
        self.hidden = hidden
        self = normalized()
    }

    /// The standard panel: every section, in the default order.
    public static let standard = PanelLayout()

    /// The sections to draw, in order.
    public var visibleSections: [PanelSection] {
        normalized().order.filter { !hidden.contains($0) }
    }

    public func isVisible(_ section: PanelSection) -> Bool {
        section.isPinned || !hidden.contains(section)
    }

    /// Shows or hides a section. Pinned sections ignore the request.
    public mutating func setVisible(_ section: PanelSection, _ visible: Bool) {
        guard !section.isPinned else { return }
        if visible { hidden.remove(section) } else { hidden.insert(section) }
    }

    /// Whether ``move(_:by:)`` can move this section one step in that
    /// direction (never past the pinned status section).
    public func canMove(_ section: PanelSection, by offset: Int) -> Bool {
        let order = normalized().order
        guard !section.isPinned, [-1, 1].contains(offset),
              let index = order.firstIndex(of: section) else { return false }
        let target = index + offset
        return order.indices.contains(target) && !order[target].isPinned
    }

    /// Swaps a section with its neighbor. No-op past either end or across the
    /// pinned status section.
    public mutating func move(_ section: PanelSection, by offset: Int) {
        guard canMove(section, by: offset) else { return }
        order = normalized().order
        guard let index = order.firstIndex(of: section) else { return }
        order.swapAt(index, index + offset)
    }

    public func normalized() -> PanelLayout {
        var seen = Set<PanelSection>()
        let rest = (order + PanelSection.allCases).filter { !$0.isPinned && seen.insert($0).inserted }
        var copy = self
        copy.order = [.status] + rest
        copy.hidden = hidden.filter { !$0.isPinned }
        return copy
    }

    private enum CodingKeys: String, CodingKey { case order, hidden }

    /// Tolerant: unknown section names (a newer build's layout) are dropped,
    /// missing sections are appended in their default order.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let order = ((try? c.decode([String].self, forKey: .order)) ?? []).compactMap(PanelSection.init(rawValue:))
        let hidden = ((try? c.decode([String].self, forKey: .hidden)) ?? []).compactMap(PanelSection.init(rawValue:))
        self.init(order: order, hidden: Set(hidden))
    }

    public func encode(to encoder: Encoder) throws {
        let value = normalized()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(value.order.map(\.rawValue), forKey: .order)
        try c.encode(value.hidden.map(\.rawValue).sorted(), forKey: .hidden)
    }
}

// MARK: - Migration from the row-level layout

extension PanelLayout {
    /// The rows of the old row-level layout that each new section absorbed.
    /// A section is hidden after migration only when every one of its rows
    /// was hidden, so nobody loses a control they could see before.
    static let legacyRows: [PanelSection: [MenuItem]] = [
        // The Automatic/Manual switch heads the session section now.
        .session: [.manualToggle, .duration, .quickStop, .manualOverride, .triggerAction],
        .triggers: [.triggersToggle, .triggerSummary, .triggerRules, .leaseStatus],
        .guards: [.closedDisplay, .brewingOnly, .lidPolicy, .batteryPause, .batteryThreshold,
                  .displaySleep, .keepActive, .dimDisplay, .screenSaverYield],
        .footer: [.preferences, .customize, .quit, .setup, .gaming, .keyboard, .wifi,
                  .welcome, .about, .updates, .support],
    ]

    /// Maps a saved row-level layout onto sections, once, the first time a
    /// layout without a ``MenuLayout/panel`` is read. A section keeps the
    /// earliest position any of its rows had, and is hidden only when all of
    /// its rows were hidden (directly, or by hiding the group they sat in).
    public init(migrating legacy: MenuLayout) {
        // An untouched row layout means the standard panel, not whatever
        // order the old default rows happen to rank in.
        var untouched = legacy.normalized()
        untouched.panel = .standard
        if untouched == MenuLayout().normalized() {
            self = .standard
            return
        }
        let layout = legacy.normalized()
        func rowHidden(_ item: MenuItem) -> Bool {
            layout.hiddenItems.contains(item) || layout.hiddenSections.contains(layout.placement(of: item))
        }
        func rank(_ section: PanelSection) -> Int {
            let rows = Self.legacyRows[section] ?? []
            let visible = rows.filter { !rowHidden($0) }
            let positions = (visible.isEmpty ? rows : visible).compactMap {
                layout.sectionOrder.firstIndex(of: layout.placement(of: $0))
            }
            return positions.min() ?? Int.max
        }
        let movable = PanelSection.allCases.filter { !$0.isPinned }
        let order = movable.enumerated()
            .sorted { lhs, rhs in
                let (l, r) = (rank(lhs.element), rank(rhs.element))
                return l == r ? lhs.offset < rhs.offset : l < r
            }
            .map(\.element)
        let hidden = movable.filter { section in (Self.legacyRows[section] ?? []).allSatisfy(rowHidden) }
        self.init(order: [.status] + order, hidden: Set(hidden))
    }
}
