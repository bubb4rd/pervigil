import SwiftUI
import AppKit
import PervigilCore
import Combine

/// Preview overrides presentation only. It cannot operate controls, register a
/// status panel, refresh hardware, or change the real panel's visibility.
struct MenuPreviewConfiguration {
    var layout: MenuLayout?
    var expanded: Bool
    var includesUnavailableItems = false
    var maxHeight: CGFloat = 480
}

/// The dropdown shown when the menu bar icon is clicked: the status card (the
/// mark, what holds the Mac, the countdown, stop), then the sections in the
/// user's order: session (Automatic or Manual, duration chips), triggers,
/// guard tiles, and the footer. Collapsed, it is the status card alone.
/// Design source: `design/concepts/combined` (prototype and NOTES.md).
struct MenuBarContent: View {
    @Bindable var model: AppModel

    /// The auto-updater behind the "Check for Updates…" item.
    let updater: any Updating

    /// Receives this panel's window, so a right-click on the icon can close
    /// the panel before showing the context menu.
    let bridge: StatusItemBridge
    var preview: MenuPreviewConfiguration? = nil

    /// Opens the window scenes declared in ``PervigilApp``.
    @Environment(\.openWindow) private var openWindow

    private var session: SessionController { model.session }

    /// Live panel values pulsed from the session ticker while open.
    private var panel: MenuPanelSnapshot { model.menuPanel }

    /// Text styles and metrics at the readability scale.
    private var type: ScaledType { ScaledType() }

    private var panelLayout: PanelLayout {
        (preview != nil ? preview?.layout : model.advancedMenuLayout)?.panel ?? .standard
    }
    private var compact: Bool { !(preview?.expanded ?? model.menuPanelExpanded) }

    /// Whether the panel is actually on screen. The closed panel keeps this
    /// view alive on current macOS, so the heavy body unmounts while false
    /// (stops Observation-graph growth) and remounts when the menu opens again.
    @State private var panelVisible = true
    @State private var previewTick = 0
    /// Held in state so each body pass reuses one timer; autoconnect only
    /// starts it for the preview, the one subscriber.
    @State private var previewTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// A compact duration like "15 min", "1 h", or "2 h 30 min".
    static func shortDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = wholeMinutes(duration)
        let hours = totalMinutes / 60, minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return L("%d h %d min", hours, minutes) }
        if hours > 0 { return L("%d h", hours) }
        return L("%d min", max(1, minutes))
    }

    /// A duration as finite whole minutes for display, saturating instead of
    /// trapping on an imported non-finite or absurd value.
    static func wholeMinutes(_ duration: TimeInterval) -> Int {
        guard duration.isFinite, duration > 0 else { return 0 }
        let capped = min(duration, SessionMode.maxTimedMinutes * 60)
        return Int((capped / 60).rounded())
    }

    /// A compact "M:SS" (or "Ns" under a minute) countdown for a grace window.
    static func graceCountdown(_ seconds: TimeInterval) -> String {
        let capped = seconds.isFinite ? min(max(0, seconds), 86_400) : 0
        let s = Int(capped.rounded(.up))
        if s >= 60 { return L("%d:%02d", s / 60, s % 60) }
        return L("%ds", s)
    }

    var body: some View {
        let _ = previewTick
        Group {
            if preview != nil {
                panelBody
                    .onReceive(previewTimer) { _ in previewTick &+= 1 }
            } else {
                livePanel
            }
        }
    }

    private var livePanel: some View {
        // Tear the heavy body down while ordered out; the visibility probe
        // stays mounted outside the `if` so reopen can remount the body.
        Group {
            if panelVisible {
                panelBody
            } else {
                Color.clear.frame(width: PanelTokens.width * type.scale, height: 1)
            }
        }
        .keepsPanelKey()
        .background(PanelWindowRegistrar { bridge.panelWindow = $0 })
        .background(WindowVisibilityReader(isVisible: $panelVisible))
        .onChange(of: panelVisible) { _, visible in
            model.menuPanelVisible = visible
            guard visible else { return }
            model.pulseMenuPanelIfVisible()
            model.refreshClosedDisplay()
        }
    }

    /// The interactive panel. Only mounted while ``panelVisible`` is true.
    @ViewBuilder
    private var panelBody: some View {
        // Date-based values (countdowns, grace) do not publish Observation
        // changes, so read the ticker's token to re-render each second.
        let _ = preview == nil ? panel.tick : UInt(previewTick)
        let status = model.panelStatus()
        let triggersControlling = model.triggersEnabled && !model.triggersPaused
        let states = triggersControlling ? (model.ruleStates() ?? []) : []
        VStack(alignment: .leading, spacing: 0) {
            if updater.updateAvailable {
                Button("Update available…", systemImage: "arrow.down.circle") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
                    .buttonStyle(.menuRow)
                    .padding([.horizontal, .top], 8)
            }
            PanelStatusCard(
                status: status,
                lidArmed: model.closedDisplayEnabled
                    || (model.closedDisplayOnlyWhileBrewing && session.isActive),
                refusedStarts: session.refusedStarts,
                compact: compact,
                onMark: { markPressed(status) },
                onKeepAwake: { model.keepAwakeFromPanel() },
                onStop: { model.performPanelStop($0) },
                onExpand: compact ? { expand() } : nil)
            if !compact {
                VStack(alignment: .leading, spacing: PanelTokens.sectionGap) {
                    if model.helperAttention != nil { helperAttentionBanner }
                    if status.state == .canSleep { heldByLine }
                    ForEach(panelLayout.visibleSections.filter { $0 != .status }) { section in
                        sectionView(section, status: status, states: states)
                    }
                    statusLines
                }
                .padding(.horizontal, PanelTokens.padding)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
        }
        .frame(width: PanelTokens.width * type.scale)
        // Keep ⌘, and ⌘Q working while the footer is folded away or hidden.
        .background {
            if preview == nil && (compact || !panelLayout.isVisible(.footer)) {
                Button("") { open(PervigilApp.preferencesWindowID) }.menuShortcut(",", enabled: true).hidden()
            }
            if preview == nil {
                Button("") { NSApplication.shared.terminate(nil) }.menuShortcut("q", enabled: true).hidden()
            }
        }
        .glassPanelBackground(brewing: session.isActive)
        .tint(.pervigilAccent)
        .font(type.body)
        .disabled(preview != nil)
        .allowsHitTesting(preview == nil)
        .onAppear {
            guard preview == nil else { return }
            model.menuPanelVisible = true
            model.pulseMenuPanelIfVisible()
            model.refreshClosedDisplay()
        }
    }

    @ViewBuilder
    private func sectionView(_ section: PanelSection, status: PanelStatus, states: [RuleState]) -> some View {
        switch section {
        case .status:
            EmptyView()
        case .session:
            PanelSessionSection(model: model)
        case .triggers:
            if (model.triggersEnabled && !model.triggersPaused) || !session.liveLeases.isEmpty {
                PanelTriggersSection(model: model, states: states, context: model.panelSourceContext(states: states))
            }
        case .guards:
            PanelGuardsSection(model: model, tiles: status.tiles)
        case .footer:
            PanelFooter(model: model, updater: updater, open: open, enabled: preview == nil)
        }
    }

    /// The mark is the primary control. During a safety pause a start is
    /// refused (the card shakes and says why) without setting triggers aside.
    private func markPressed(_ status: PanelStatus) {
        switch status.state {
        case .awake: model.performPanelStop(status.stop ?? .stopSession)
        case .paused: session.start(mode: model.defaultMode)
        case .canSleep: model.keepAwakeFromPanel()
        }
    }

    /// The window snaps to the full panel in one non-animated transaction: an
    /// animated resize interrupted by the next change can leave the panel
    /// window stuck at a stale height.
    private func expand() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { model.menuPanelExpanded = true }
    }

    /// Dismisses the dropdown, then opens a window scene with the app brought
    /// forward. Pervigil is an `LSUIElement` agent, so a sibling window would
    /// otherwise order behind the still-key panel. `@Environment(\.dismiss)`
    /// isn't reliable for this panel, so ask the bridge to end the session.
    private func open(_ id: String) {
        guard preview == nil else { return }
        bridge.dismissPanel()
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: id)
    }

    // MARK: - Status lines

    /// A warning row shown while the privileged helper needs the user.
    private var helperAttentionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("The helper needs attention")
                    .font(type.callout.weight(.medium))
                Text(model.helperAttention == .needsApproval
                    ? L("Approve Pervigil again in System Settings.")
                    : model.helper.lastError ?? L("The helper isn't responding; reinstall it."))
                    .font(type.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Fix\u{2026}") { open(PervigilApp.helperWindowID) }
        }
        .padding(8)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Another app holding the Mac awake while Pervigil isn't, with that
    /// app's own icon.
    @ViewBuilder
    private var heldByLine: some View {
        if let held = panel.heldBy {
            HStack(spacing: 6) {
                SourceIcon(source: .app(bundleID: nil, bundlePath: nil, pid: held.pid), size: 15)
                    .foregroundStyle(.secondary)
                Text("\(held.processName): \(held.effect.lowercased())")
                    .font(type.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    /// The fan boost and the AWDL pause, when either is active.
    @ViewBuilder
    private var statusLines: some View {
        if let percent = model.fanBoostActivePercent {
            statusLine(icon: "fanblades", color: .orange, text: L("Fans boosted to %d%% to cool the Mac", percent))
        }
        if model.awdlStatus.isPausing, let status = AWDLStatusStyle(model.awdlStatus) {
            statusLine(icon: status.icon, color: status.color, text: status.text)
        }
    }

    private func statusLine(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(type.caption)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(text)
                .font(type.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private extension View {
    func menuShortcut(_ key: KeyEquivalent, enabled: Bool) -> some View {
        keyboardShortcut(enabled ? KeyboardShortcut(key, modifiers: .command) : nil)
    }
}
