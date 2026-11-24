import SwiftUI
import PervigilCore

/// The trigger list, flat on the panel: a tinted category icon carries each
/// rule's state (green when met, amber in grace), the right side names the
/// app or place behind it, agents get their own rows with their marks, and
/// automation leases sit under a hairline with a way to end them.
struct PanelTriggersSection: View {
    @Bindable var model: AppModel
    let states: [RuleState]
    let context: PanelSourceContext
    /// Collapses past this many agent rows into stacked marks with "+n".
    static let maxAgentRows = 3

    @State private var agentsExpanded = false

    private var session: SessionController { model.session }
    private var showsRules: Bool { model.triggersEnabled && !model.triggersPaused }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsRules {
                header
                if states.isEmpty {
                    Text("No conditions yet. Add some in Preferences ▸ Triggers.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                } else {
                    ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                        ruleRow(state)
                        if case .agentActivity = state.rule, !state.details.isEmpty {
                            agentRows(state.details)
                        }
                    }
                }
            }
            if !session.liveLeases.isEmpty {
                leaseRows
            }
        }
    }

    private var header: some View {
        let met = states.filter { $0.satisfied || $0.inGrace }.count
        return HStack {
            Text(model.combine == .all ? L("Awake while all are met") : L("Awake while any is met"))
                .font(.system(size: 11, weight: .semibold))
            Spacer()
            Text(L("%d of %d", met, states.count)).font(.system(size: 11)).monospacedDigit()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    // MARK: Rule rows

    private func ruleRow(_ state: RuleState) -> some View {
        let tone: RuleTone = state.inGrace ? .grace : (state.satisfied ? .met : .unmet)
        return HStack(spacing: 8) {
            Image(systemName: state.rule.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 20, height: 20)
                .foregroundStyle(tone.ink)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tone.fill))
                .contentTransition(.symbolEffect(.replace))
                .animation(.easeInOut(duration: 0.25), value: tone)
            HStack(spacing: 4) {
                Text(title(for: state.rule))
                    .font(.system(size: 12.5, weight: tone == .unmet ? .regular : .medium))
                    .foregroundStyle(tone == .unmet ? Color.secondary : Color.primary)
                if let note = note(for: state.rule) {
                    Text(note).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .truncationMode(.middle)
            Spacer(minLength: 6)
            trailing(state)
        }
        .frame(height: 26)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(tone == .grace ? L("Met, in grace period") : (tone == .met ? L("Met") : L("Not met")))
    }

    @ViewBuilder
    private func trailing(_ state: RuleState) -> some View {
        if state.inGrace, let remaining = state.graceRemaining {
            Text(MenuBarContent.graceCountdown(remaining))
                .font(.system(size: 11.5, weight: .semibold)).monospacedDigit()
                .foregroundStyle(Color.panelAmberText)
                .contentTransition(.numericText(countsDown: true))
        } else if state.satisfied, let source = PanelStatus.rowSource(for: state.rule, context: context),
                  let name = sourceName(source) {
            HStack(spacing: 5) {
                SourceIcon(source: source, size: 16)
                Text(name).lineLimit(1).truncationMode(.middle)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .frame(maxWidth: 132, alignment: .trailing)
        }
    }

    /// The agent rule reads "AI agent working" with its grace as a quieter
    /// note; every other rule keeps its own label.
    private func title(for rule: TriggerRule) -> String {
        if case .agentActivity = rule { return L("AI agent working") }
        return rule.label
    }

    private func note(for rule: TriggerRule) -> String? {
        guard case .agentActivity(let agent) = rule, agent.grace > 0 else { return nil }
        return L("(%@ grace)", MenuBarContent.shortDuration(agent.grace))
    }

    private func sourceName(_ source: TriggerSource) -> String? {
        switch source {
        case .file(let url): return url.lastPathComponent
        case .app: return AppIconProvider.shared.name(for: source)
        default: return nil
        }
    }

    // MARK: Agent rows

    @ViewBuilder
    private func agentRows(_ details: [RuleDetail]) -> some View {
        let ordered = details.enumerated().sorted { lhs, rhs in
            lhs.element.active == rhs.element.active ? lhs.offset < rhs.offset : lhs.element.active
        }.map(\.element)
        let collapses = ordered.count > Self.maxAgentRows && !agentsExpanded
        let shown = collapses ? Array(ordered.prefix(Self.maxAgentRows - 1)) : ordered
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, detail in
                agentRow(detail)
            }
            if collapses {
                collapsedRow(Array(ordered.dropFirst(shown.count)))
            } else if ordered.count > Self.maxAgentRows {
                Button(L("Show less")) { withAnimation(.snappy(duration: 0.25)) { agentsExpanded = false } }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 25)
                    .frame(height: 23)
            }
        }
        .padding(.leading, 29)
        .padding(.bottom, 3)
    }

    private func agentRow(_ detail: RuleDetail) -> some View {
        HStack(spacing: 7) {
            AgentLogo(agent: detail.agent)
                .opacity(detail.active ? 1 : 0.4)
            Text(detail.label)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text(detail.active ? L("working") : L("idle"))
                .font(.system(size: 11, weight: detail.active ? .semibold : .regular))
                .foregroundStyle(detail.active ? Self.agentInk(detail.agent) : Color.secondary)
        }
        .frame(height: 23)
    }

    private func collapsedRow(_ rest: [RuleDetail]) -> some View {
        let busy = rest.filter(\.active).count
        let first = rest.first?.agent.map(AgentNames.displayName) ?? rest.first?.label ?? ""
        return Button {
            withAnimation(.snappy(duration: 0.25)) { agentsExpanded = true }
        } label: {
            HStack(spacing: 7) {
                HStack(spacing: -5) {
                    ForEach(Array(rest.prefix(3).enumerated()), id: \.offset) { index, detail in
                        AgentLogo(agent: detail.agent)
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                            .zIndex(Double(3 - index))
                    }
                }
                HStack(spacing: 4) {
                    Text(first).lineLimit(1)
                    if rest.count > 1 {
                        Text(verbatim: "+\(rest.count - 1)").fontWeight(.semibold).foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12))
                Spacer(minLength: 4)
                Text(busy > 0 ? L("%d working", busy) : L("idle"))
                    .font(.system(size: 11, weight: busy > 0 ? .semibold : .regular))
                    .foregroundStyle(busy > 0 ? Color.primary : Color.secondary)
            }
            .frame(height: 23)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Show %d more agents", rest.count))
    }

    static func agentInk(_ agent: String?) -> Color {
        switch agent {
        case "claude": return .claudeAccent
        case "gemini": return AppIconProvider.agentTint("gemini") ?? .primary
        default: return .primary
        }
    }

    // MARK: Leases

    private var leaseRows: some View {
        let leases = Array(session.liveLeases.prefix(3))
        return VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.top, showsRules ? 5 : 0)
            ForEach(Array(leases.enumerated()), id: \.element.id) { index, lease in
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.panelAccentText)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.panelAccentText.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            if AgentNames.known.contains(lease.tool.lowercased()) {
                                SourceIcon(source: .agent(lease.tool.lowercased()), size: 14)
                            }
                            Text(lease.task).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                        }
                        Text(L("Lease, ends in %@", MenuBarContent.graceCountdown(max(0, lease.expiresAt.timeIntervalSinceNow))))
                            .font(.system(size: 11)).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 6)
                    if index == leases.count - 1 {
                        Button(session.liveLeases.count == 1 ? L("End") : L("End all")) { model.endAutomationLeases() }
                            .buttonStyle(QuietButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
            if session.liveLeases.count > leases.count {
                Text(L("and %d more", session.liveLeases.count - leases.count))
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 30)
            }
        }
    }
}

private enum RuleTone: Equatable {
    case met, grace, unmet
    var ink: Color {
        switch self {
        case .met: .panelGreenText
        case .grace: .panelAmberText
        case .unmet: .secondary
        }
    }
    var fill: Color {
        switch self {
        case .met: Color.panelGreenText.opacity(0.15)
        case .grace: Color.panelAmberDot.opacity(0.16)
        case .unmet: Color.primary.opacity(0.06)
        }
    }
}

/// An agent's logo in a small rounded square tinted with its brand: Claude's
/// own tile, Gemini's blue, the label color for monochrome marks.
struct AgentLogo: View {
    let agent: String?
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let agent {
                let source = TriggerSource.agent(agent)
                switch AppIconProvider.shared.icon(for: source) {
                case .image, .claudeTile:
                    SourceIcon(source: source, size: size)
                default:
                    SourceIcon(source: source, size: size * 0.7)
                        .frame(width: size, height: size)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint))
                }
            } else {
                Circle().fill(Color.secondary).frame(width: 4, height: 4).frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }

    private var tint: Color {
        if agent == "gemini" { return Color(red: 0.43, green: 0.55, blue: 0.97).opacity(0.18) }
        return Color.primary.opacity(0.1)
    }
}

/// A small neutral button (End, Stop) that sits quietly next to text.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.1)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
