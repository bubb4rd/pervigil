import SwiftUI
import AppKit
import PervigilCore

// MARK: - Tokens

/// The redesigned panel's tokens (see `design/concepts/combined/NOTES.md`).
enum PanelTokens {
    static let width: CGFloat = 320
    static let padding: CGFloat = 12
    static let sectionGap: CGFloat = 12
}

extension Color {
    /// The mark tile while awake: the brand blue deepened one step so the
    /// white mark keeps contrast (#3A8FF2 to #0068E0).
    static let panelTileTop = Color(red: 58 / 255, green: 143 / 255, blue: 242 / 255)
    static let panelTileBottom = Color(red: 0, green: 104 / 255, blue: 224 / 255)
    /// Filled controls (Keep awake, selected chips, the on-tile icon): #006BE0
    /// in both modes so white labels keep 5:1+ contrast.
    static let panelAccentSolid = Color(red: 0, green: 107 / 255, blue: 224 / 255)
    /// Accent text and icons on the panel.
    static let panelAccentText = dynamic(light: (0, 89, 194), dark: (130, 187, 249))
    /// Warnings: battery near its limit, a grace countdown, a pause.
    static let panelAmberText = dynamic(light: (143, 68, 0), dark: (255, 184, 81))
    static let panelAmberDot = dynamic(light: (201, 106, 0), dark: (255, 159, 10))
    /// A met trigger.
    static let panelGreenText = dynamic(light: (20, 117, 50), dark: (74, 222, 128))

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: 1)
        })
    }
}

/// The panel's spring and fade, or plain fades under Reduce Motion.
enum PanelMotion {
    static func spring(_ reduce: Bool) -> Animation? { reduce ? nil : .spring(duration: 0.3, bounce: 0.25) }
    static func swap(_ reduce: Bool) -> AnyTransition {
        reduce ? .opacity : .scale(scale: 0.55).combined(with: .opacity)
    }
}

// MARK: - Status card

/// The top of the panel: the mark as the primary control, the state and why,
/// the countdown, and stop. The compact strip is this card on its own.
struct PanelStatusCard: View {
    let status: PanelStatus
    /// Bar level of a timed session, 1 (full) down to 0.
    let lidArmed: Bool
    let refusedStarts: Int
    var compact = false
    let onMark: () -> Void
    let onKeepAwake: () -> Void
    let onStop: (PanelStatus.StopAction) -> Void
    var onExpand: (() -> Void)? = nil

    @State private var stopHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                PanelMarkButton(
                    state: status.state, held: status.heldByAutomation,
                    level: status.progress ?? 1, lidArmed: lidArmed,
                    size: compact ? 60 : 52, action: onMark)
                    .shakes(on: refusedStarts)
                VStack(alignment: .leading, spacing: 1) {
                    Text(status.title)
                        .font(.system(size: compact ? 17 : 15, weight: .semibold))
                        .contentTransition(.opacity)
                    if let subtitle = status.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(status.tone == .warning ? Color.panelAmberText : Color.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.numericText())
                    }
                    if !status.reasons.isEmpty {
                        ReasonStack(reasons: status.reasons).padding(.top, 4)
                    }
                    if let detail = status.detail {
                        Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
                if let onExpand {
                    Button(action: onExpand) {
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(L("Show full panel"))
                    .accessibilityLabel(L("Show full panel"))
                }
            }
            .padding(compact ? 14 : PanelTokens.padding)
            if let progress = status.progress {
                ProgressLine(value: progress)
                    .opacity(stopHovered ? 0.45 : 1)
                    .padding(.horizontal, compact ? 0 : PanelTokens.padding)
                    .transition(.opacity)
            }
        }
        .animation(PanelMotion.spring(reduceMotion), value: status.stop != nil)
        .animation(.easeInOut(duration: 0.2), value: stopHovered)
    }

    private var trailing: some View {
        HStack(spacing: 8) {
            if let countdown = status.countdown {
                Text(MenuBarLabel.format(countdown))
                    .font(.system(size: 22, weight: .medium))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .opacity(stopHovered ? 0.45 : 1)
                    .accessibilityLabel(L("Time left"))
                    .accessibilityValue(MenuBarLabel.format(countdown))
            } else if let clock = status.clock {
                StatusClock(clock: clock)
                    .opacity(stopHovered ? 0.45 : 1)
            }
            ZStack {
                if let action = status.stop {
                    StopButton(action: action, hovered: $stopHovered) { onStop(action) }
                        .transition(PanelMotion.swap(reduceMotion))
                } else {
                    Button(L("Keep awake"), action: onKeepAwake)
                        .buttonStyle(KeepAwakeButtonStyle())
                        .transition(PanelMotion.swap(reduceMotion))
                }
            }
        }
    }
}

// MARK: - Mark button

/// The Pervigil mark as a button: grey while the Mac can sleep, the blue tile
/// while held, amber during a safety pause. Its left bar drains with a timed
/// session, and a small triangle fills the play cutout (breathing) while a
/// trigger rather than the user holds the Mac.
struct PanelMarkButton: View {
    let state: PanelStatus.State
    let held: Bool
    let level: Double
    let lidArmed: Bool
    let size: CGFloat
    let action: () -> Void

    @State private var hovering = false
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                    .fill(background)
                markLayers
                    .frame(width: size * 0.54 * BrandMark.aspectRatio, height: size * 0.54)
                    .foregroundStyle(ink)
            }
            .frame(width: size, height: size)
            .shadow(color: state == .awake ? Color.panelTileBottom.opacity(0.35) : .clear, radius: 5, y: 3)
            .overlay(alignment: .bottomTrailing) {
                if lidArmed {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.panelAccentText)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                        .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
                        .offset(x: 5, y: 5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PressScaleStyle(scale: 0.93))
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(state == .awake ? .isSelected : [])
        .animation(.easeInOut(duration: 0.3), value: state)
        .onAppear { breathe = true }
    }

    private var markLayers: some View {
        ZStack {
            MarkPart(part: .body).fill(style: FillStyle(eoFill: true))
            MarkPart(part: .bar(level: 1)).opacity(0.32)
            MarkPart(part: .bar(level: level)).animation(.linear(duration: 0.9), value: level)
            MarkPart(part: .inner)
                .opacity(innerOpacity)
                .animation(held && !reduceMotion
                    ? .easeInOut(duration: 1.3).repeatForever(autoreverses: true) : .easeInOut(duration: 0.25),
                    value: breathe && held)
        }
    }

    private var innerOpacity: Double {
        if held { return reduceMotion || !breathe ? 1 : 0.4 }
        return state == .canSleep && hovering ? 0.45 : 0
    }

    private var background: AnyShapeStyle {
        switch state {
        case .awake:
            AnyShapeStyle(LinearGradient(colors: [.panelTileTop, .panelTileBottom], startPoint: .top, endPoint: .bottom))
        case .paused: AnyShapeStyle(Color.panelAmberDot.opacity(0.18))
        case .canSleep: AnyShapeStyle(Color.primary.opacity(hovering ? 0.14 : 0.1))
        }
    }

    private var ink: Color {
        switch state {
        case .awake: .white
        case .paused: .panelAmberText
        case .canSleep: .secondary
        }
    }

    private var label: String {
        switch state {
        case .awake: L("Stop keeping awake")
        case .paused: L("Paused by battery guard")
        case .canSleep: L("Keep awake")
        }
    }
}

/// One layer of the mark in its 562 x 650 viewBox, fitted like ``BrandMark``.
struct MarkPart: Shape {
    enum Part: Equatable { case body, bar(level: Double), inner }
    var part: Part

    var animatableData: Double {
        get { if case .bar(let level) = part { return level }; return 0 }
        set { if case .bar = part { part = .bar(level: newValue) } }
    }

    func path(in rect: CGRect) -> Path {
        let p = CGMutablePath()
        switch part {
        case .body:
            // The block minus the left bar and the play cutout.
            p.addLines(between: [CGPoint(x: 0, y: 0), CGPoint(x: 562, y: 0), CGPoint(x: 562, y: 650),
                                 CGPoint(x: 190, y: 650), CGPoint(x: 190, y: 645), CGPoint(x: 557, y: 438),
                                 CGPoint(x: 190, y: 231), CGPoint(x: 0, y: 124)])
            p.closeSubpath()
        case .bar(let level):
            let clamped = min(1, max(0, level))
            let height = 419 * clamped
            p.addRect(CGRect(x: 0, y: 650 - height, width: 190, height: height))
        case .inner:
            p.addLines(between: [CGPoint(x: 251, y: 334), CGPoint(x: 435, y: 438), CGPoint(x: 251, y: 542)])
            p.closeSubpath()
        }
        var t = BrandMark.transform(fitting: rect)
        return Path(p.copy(using: &t) ?? p)
    }
}

// MARK: - Reason stack

/// The reasons as an overlapping stack of icons with no backgrounds, like
/// avatar rows. Each icon after the first is notched where the one before it
/// sits, so the overlap stays clean on the translucent panel. Past four, three
/// icons and a "+n". Hovering fans the icons apart.
struct ReasonStack: View {
    let reasons: [PanelReason]
    static let maxShown = 4

    @State private var spread = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = reasons.count > Self.maxShown ? Array(reasons.prefix(Self.maxShown - 1)) : reasons
        let rest = reasons.dropFirst(shown.count)
        HStack(spacing: spread ? 3 : -4) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, reason in
                item(reason)
                    .modifier(NotchMask(active: index > 0 && !spread && reason.kind != .grace))
                    .zIndex(Double(shown.count - index))
                    .help(reason.label)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            if !rest.isEmpty {
                Text(verbatim: "+\(rest.count)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, spread ? 2 : 9)
                    .help(rest.map(\.label).joined(separator: "\n"))
            }
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.3)) { spread = hovering }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reasons.map(\.label).joined(separator: ", "))
    }

    @ViewBuilder
    private func item(_ reason: PanelReason) -> some View {
        if reason.kind == .grace {
            HStack(spacing: 3) {
                Image(systemName: "clock").font(.system(size: 12, weight: .semibold))
                if let countdown = reason.countdown {
                    Text(MenuBarContent.graceCountdown(countdown))
                        .font(.system(size: 11.5, weight: .semibold)).monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            .foregroundStyle(Color.panelAmberText)
        } else {
            SourceIcon(source: reason.source, size: 20)
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }
}

/// Cuts a small circle out of an icon's left edge where the icon before it
/// sits: a transparent notch instead of a painted ring.
private struct NotchMask: ViewModifier {
    var active: Bool
    func body(content: Content) -> some View {
        content.mask {
            ZStack {
                Rectangle()
                if active {
                    Circle().frame(width: 22, height: 22).offset(x: -16).blendMode(.destinationOut)
                }
            }
            .compositingGroup()
        }
    }
}

// MARK: - Stop and Keep awake

/// Stop as a round X to the right of the timer. Hover deepens the fill and
/// turns the X a quarter turn on a spring; the card fades the timer back to
/// preview the end.
struct StopButton: View {
    let action: PanelStatus.StopAction
    @Binding var hovered: Bool
    let perform: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: perform) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .rotationEffect(.degrees(hovered && !reduceMotion ? 90 : 0))
                .frame(width: 26, height: 26)
                .background(Circle().fill(fill))
                .overlay(Circle().stroke(Color.primary.opacity(hovered ? 0.12 : 0), lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.86))
        .foregroundStyle(action == .endPausedSession ? Color.panelAmberText : (hovered ? Color.primary : Color.secondary))
        .onHover { inside in
            withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3)) { hovered = inside }
        }
        .help(label)
        .accessibilityLabel(label)
    }

    private var fill: Color {
        if action == .endPausedSession { return Color.panelAmberDot.opacity(hovered ? 0.26 : 0.18) }
        return Color.primary.opacity(hovered ? 0.14 : 0.08)
    }

    private var label: String {
        switch action {
        case .stopSession: L("Stop keeping awake")
        case .setTriggersAside: L("Set triggers aside and let the Mac sleep")
        case .endLeases: L("End automation leases")
        case .endPausedSession: L("End the paused session")
        }
    }
}

struct KeepAwakeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.panelAccentSolid))
            .brightness(configuration.isPressed ? -0.06 : 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
    }
}

/// Scales a control down while pressed, springing back on release.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(duration: 0.18, bounce: 0.3), value: configuration.isPressed)
    }
}

/// The hairline under a timed session, showing how much is left.
struct ProgressLine: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule().fill(Color.panelAccentText)
                    .frame(width: geo.size.width * min(1, max(0, value)))
                    .animation(.linear(duration: 0.9), value: value)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

/// The clock in the countdown's spot when nothing counts down: how long
/// triggers or a no-limit session have held the Mac, or, in amber, the grace
/// window before it may sleep. A small caption above says which.
private struct StatusClock: View {
    let clock: PanelClock

    private var caption: String {
        switch clock {
        case .heldFor: L("held for")
        case .awakeFor: L("awake for")
        case .grace: L("sleeps in")
        }
    }
    private var seconds: TimeInterval {
        switch clock {
        case .heldFor(let t), .awakeFor(let t), .grace(let t): t
        }
    }
    private var isGrace: Bool {
        if case .grace = clock { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(caption)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isGrace ? AnyShapeStyle(Color.panelAmberText) : AnyShapeStyle(.secondary))
            Text(MenuBarLabel.format(seconds))
                .font(.system(size: 22, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: isGrace))
                .foregroundStyle(isGrace ? AnyShapeStyle(Color.panelAmberText) : AnyShapeStyle(.primary))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue(MenuBarLabel.format(seconds))
    }
}
