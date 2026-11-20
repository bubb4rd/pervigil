import SwiftUI
import AppKit

/// Template images for the system menu bar, rendered from ``BrandMark``: the
/// solid mark always, so the bar shows the logo itself, plus a small dot at
/// the lower right whenever the Mac is held awake. Template (monochrome) so
/// macOS tints them for the bar's appearance and highlight state, exactly
/// like an SF Symbol. A badge rather than a dimmed idle mark, because macOS
/// already dims every status item on an inactive display.
@MainActor
enum MenuBarIcon {
    /// The canvas every state shares. The status item never widens for
    /// changed label content (see ``MenuBarLabel``), so all states, the
    /// hidden sliver aside, use this one size.
    static let canvas = CGSize(width: 18, height: 18)
    /// The mark's height inside the canvas, about a cap height taller than
    /// the menu bar's text so it sits level with SF Symbols next to it.
    static let markHeight: CGFloat = 15
    /// The outline width for the pause and low-battery states, drawn entirely
    /// inside the mark so every state shares one footprint.
    static let outlineWidth: CGFloat = 1.2
    /// The awake badge: a dot at the mark's lower right, with a transparent
    /// gap cut around it so it reads at menu-bar size.
    nonisolated static let badgeRadius: CGFloat = 2.4
    nonisolated static let badgeGap: CGFloat = 1.2

    static let idle = render(.idle)
    static let active = render(.active)
    /// A trigger or automation lease holds the Mac: the solid mark with a
    /// small triangle filling the play cutout, the panel button's sign.
    static let held = render(.held)
    /// A safety pause (battery or thermal): the outer outline with two pause
    /// bars where the play cutout was. Play turns into pause, which reads at
    /// menu-bar size where a thin yellow band did not.
    static let paused = render(.paused)
    /// A timed session: the solid mark with the left bar draining, quantized
    /// to eighths so only eight images ever exist. Index 0 is nearly empty,
    /// 7 is full.
    static let timedLevels: [NSImage] = (1...8).map { render(.timed(eighths: $0)) }

    /// The timed image for a remaining share, 0 through 1.
    static func timed(level: Double) -> NSImage {
        let eighths = min(8, max(1, Int((level * 8).rounded(.up))))
        return timedLevels[eighths - 1]
    }
    /// The battery pause: the idle outline with its lowest band filled in
    /// the system's low-power yellow, the last of the charge. The band is the
    /// only colored ink, subtle but unambiguous next to the plain outline.
    /// Not a template image (a template would flatten the yellow); the
    /// outline uses the dynamic label color so it matches the bar in both
    /// appearances.
    static let pausedLowBattery = render(.lowBattery)
    /// A blank 1pt sliver the custom label shows in place of the mark when
    /// the icon is turned off. Keeping one `Image` in the label at all times
    /// means turning the icon back on swaps this image for a wider one, which
    /// the status item does resize for, instead of inserting a sibling
    /// `Image`, which it clips (see ``MenuBarLabel``).
    static let hidden: NSImage = {
        let image = NSImage(size: NSSize(width: 1, height: canvas.height), flipped: true) { _ in true }
        image.isTemplate = true
        return image
    }()

    private enum State: Equatable { case idle, active, lowBattery, held, paused, timed(eighths: Int) }

    private static var markRect: CGRect {
        let width = markHeight * BrandMark.aspectRatio
        // Left-aligned with the old 16 pt canvas's inset, leaving the extra
        // width on the right for the awake badge.
        return CGRect(x: (16 - width) / 2, y: (canvas.height - markHeight) / 2,
                      width: width, height: markHeight)
    }

    private static func render(_ state: State) -> NSImage {
        let image = NSImage(size: canvas, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let rect = markRect
            let mark = BrandMark.path(fitting: rect)
            let ink = state == .lowBattery ? NSColor.labelColor.cgColor : NSColor.black.cgColor

            var fit = BrandMark.transform(fitting: rect)
            func fitted(_ points: [CGPoint]) -> CGPath {
                let p = CGMutablePath()
                p.addLines(between: points)
                p.closeSubpath()
                return p.copy(using: &fit) ?? p
            }
            // The awake badge: punch a gap, then the dot, over whatever the
            // state drew.
            func badge() {
                let center = CGPoint(x: rect.maxX + 0.6, y: rect.maxY - 1.6)
                ctx.saveGState()
                ctx.setBlendMode(.clear)
                let gap = badgeRadius + badgeGap
                ctx.fillEllipse(in: CGRect(x: center.x - gap, y: center.y - gap, width: gap * 2, height: gap * 2))
                ctx.restoreGState()
                ctx.setFillColor(ink)
                ctx.fillEllipse(in: CGRect(x: center.x - badgeRadius, y: center.y - badgeRadius,
                                           width: badgeRadius * 2, height: badgeRadius * 2))
            }
            switch state {
            case .idle, .active, .held:
                ctx.setFillColor(ink)
                ctx.addPath(mark)
                ctx.fillPath(using: .evenOdd)
                if state == .held {
                    ctx.addPath(fitted([CGPoint(x: 251, y: 334), CGPoint(x: 435, y: 438), CGPoint(x: 251, y: 542)]))
                    ctx.fillPath()
                }
                if state != .idle { badge() }
                return true
            case .timed(let eighths):
                // The block without its left bar, then the bar as a track
                // and the remaining share filled from the bottom.
                ctx.setFillColor(ink)
                ctx.addPath(fitted([CGPoint(x: 0, y: 0), CGPoint(x: 562, y: 0), CGPoint(x: 562, y: 650),
                                    CGPoint(x: 190, y: 650), CGPoint(x: 190, y: 645), CGPoint(x: 557, y: 438),
                                    CGPoint(x: 190, y: 231), CGPoint(x: 0, y: 124)]))
                ctx.fillPath()
                let height = 419 * CGFloat(eighths) / 8
                ctx.setFillColor(NSColor.black.withAlphaComponent(0.32).cgColor)
                ctx.addPath(fitted([CGPoint(x: 0, y: 231), CGPoint(x: 190, y: 231), CGPoint(x: 190, y: 650), CGPoint(x: 0, y: 650)]))
                ctx.fillPath()
                ctx.setFillColor(ink)
                ctx.addPath(fitted([CGPoint(x: 0, y: 650 - height), CGPoint(x: 190, y: 650 - height),
                                    CGPoint(x: 190, y: 650), CGPoint(x: 0, y: 650)]))
                ctx.fillPath()
                badge()
                return true
            case .paused:
                var t = fit
                let outer = BrandMark.silhouette().copy(using: &t) ?? BrandMark.silhouette()
                ctx.saveGState()
                ctx.addPath(outer)
                ctx.clip()
                ctx.setStrokeColor(ink)
                ctx.setLineWidth(outlineWidth * 2)
                ctx.addPath(outer)
                ctx.strokePath()
                ctx.restoreGState()
                ctx.setFillColor(ink)
                ctx.addPath(fitted([CGPoint(x: 250, y: 300), CGPoint(x: 322, y: 300), CGPoint(x: 322, y: 576), CGPoint(x: 250, y: 576)]))
                ctx.addPath(fitted([CGPoint(x: 384, y: 300), CGPoint(x: 456, y: 300), CGPoint(x: 456, y: 576), CGPoint(x: 384, y: 576)]))
                ctx.fillPath()
                return true
            case .lowBattery:
                break
            }

            // Clip to the mark and stroke at twice the width: an inner
            // stroke, so the outline keeps the solid mark's exact footprint.
            ctx.addPath(mark)
            ctx.clip(using: .evenOdd)
            ctx.setStrokeColor(ink)
            ctx.setLineWidth(outlineWidth * 2)
            ctx.addPath(mark)
            ctx.strokePath()
            if state == .lowBattery {
                // Over the outline, so the band reads as one solid level.
                let level = rect.height * BrandMark.lowBatteryLevel
                ctx.setFillColor(NSColor.systemYellow.cgColor)
                ctx.fill(CGRect(x: rect.minX, y: rect.maxY - level, width: rect.width, height: level))
            }
            return true
        }
        image.isTemplate = state != .lowBattery
        return image
    }
}

/// The mark as a SwiftUI shape, fitted to its frame with the aspect ratio
/// kept. Fill it with `FillStyle(eoFill: true)` so the play cut reads as a
/// hole.
struct BrandMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(BrandMark.path(fitting: rect))
    }
}

/// The mark for real windows, where color runs normally: the brand gradient
/// (#6EAFF6 to #007AFF) when active, a secondary outline when idle. `fill` is
/// the blend between them, 0 (outline) through 1 (solid); ``BrandMarkView``
/// animates it as a short crossfade.
struct BrandMarkGlyph: View {
    var fill: CGFloat
    /// The battery pause: the idle outline with its lowest band in the
    /// low-power yellow, matching ``MenuBarIcon/pausedLowBattery`` so the
    /// menu header and the bar tell the same story.
    var lowBattery = false

    init(filled: Bool, lowBattery: Bool = false) {
        fill = filled ? 1 : 0
        self.lowBattery = lowBattery
    }
    init(fill: CGFloat, lowBattery: Bool = false) {
        self.fill = min(1, max(0, fill))
        self.lowBattery = lowBattery
    }

    private static let eoFill = FillStyle(eoFill: true)

    var body: some View {
        GeometryReader { geo in
            // The outline width tracks the mark's size, matching the menu
            // bar's proportions (1.2 pt on a 15 pt mark).
            let lineWidth = max(1, geo.size.height * MenuBarIcon.outlineWidth / MenuBarIcon.markHeight)
            ZStack {
                ZStack {
                    BrandMarkShape()
                        .stroke(Color.secondary, lineWidth: lineWidth * 2)
                    // Over the outline, so the band reads as one solid level.
                    if lowBattery {
                        Color(nsColor: .systemYellow)
                            .frame(height: geo.size.height * BrandMark.lowBatteryLevel)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .clipShape(BrandMarkShape(), style: Self.eoFill)
                .opacity(1 - fill)

                BrandMarkShape()
                    .fill(
                        LinearGradient(colors: [.brandMarkTop, .brandMarkBottom],
                                       startPoint: .top, endPoint: .bottom),
                        style: Self.eoFill)
                    .opacity(fill)
            }
        }
        .aspectRatio(BrandMark.aspectRatio, contentMode: .fit)
    }
}

/// The brand mark with its session state, for the menu header and other real
/// windows: solid in the brand gradient while a session runs, a quiet outline
/// while idle, and the outline with a low yellow band during the battery
/// pause. A state change is a short crossfade, and instant under Reduce
/// Motion. The menu bar *label* is a static template image of the same mark
/// (``MenuBarIcon``), since a `MenuBarExtra` label is snapshotted.
struct BrandMarkView: View {
    /// Whether a session is running.
    var isActive: Bool

    /// Whether the battery pause is holding the session.
    var pausedLowBattery: Bool = false

    /// Size multiplier over the menu-header size (19 x 22 pt). The outline
    /// scales with it, so a window header can show the same mark large and
    /// still crisp.
    var scale: CGFloat = 1

    /// The mark's height at scale 1.
    static let baseHeight: CGFloat = 22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The animated blend (0 outline, 1 solid). Seeded from `isActive` so a
    /// view that renders only one frame (a window snapshot, a modal opening)
    /// shows the right state rather than starting from the outline.
    @State private var fill: CGFloat

    init(isActive: Bool, pausedLowBattery: Bool = false, scale: CGFloat = 1) {
        self.isActive = isActive
        self.pausedLowBattery = pausedLowBattery
        self.scale = scale
        _fill = State(initialValue: isActive ? 1 : 0)
    }

    var body: some View {
        BrandMarkGlyph(fill: fill, lowBattery: pausedLowBattery && !isActive)
            .frame(width: Self.baseHeight * BrandMark.aspectRatio * scale,
                   height: Self.baseHeight * scale)
            .accessibilityHidden(true) // the header text next to it carries the status
            .onChange(of: isActive) { _, active in
                if reduceMotion {
                    fill = active ? 1 : 0
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) { fill = active ? 1 : 0 }
                }
            }
    }
}
