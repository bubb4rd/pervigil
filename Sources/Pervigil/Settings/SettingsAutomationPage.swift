import SwiftUI
import PervigilCore

/// Automation: let agents and scripts hold the Mac awake, wake it for
/// scheduled work, and act when a session ends. Sections follow the order
/// things happen in an unattended run: wake, hold, work, then.
struct SettingsAutomationPage: View {
    @Bindable var model: AppModel
    let navigate: (SettingsPage, String?) -> Void
    @State private var draft: HookDraft?
    @State private var editingID: UUID?
    /// Transient feedback after a copy action, with paste guidance.
    @State private var copied: Copied?
    @State private var copiedTask: Task<Void, Never>?

    private enum Copied: Equatable { case access(String), runInstructions }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                    AutomationFlow(steps: flowSteps) { anchor in
                        withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(anchor, anchor: .top) }
                    }
                    .settingsAnchor("flow")
                } header: {
                    PageHeader(page: .automation, summary: L("Let agents and scripts hold the Mac awake, wake it for scheduled work, and act when a session ends."))
                } footer: {
                    sectionFooter("How the settings below chain together for an unattended run. Click a step to jump to it.")
                }
                accessSection
                automationSyncSection
                scheduledWakeSection
                endActionSection
                eventHooksSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .animation(.snappy(duration: 0.25), value: model.endAction)
        .animation(.snappy(duration: 0.25), value: model.wakeSchedule != nil)
        .animation(.snappy(duration: 0.25), value: model.automationSyncConfig.enabled)
        .animation(.snappy(duration: 0.25), value: model.automationSyncConfig.enabledSources)
        .animation(.snappy(duration: 0.25), value: model.helperInstalled)
        .animation(.snappy(duration: 0.25), value: copied)
        .sheet(item: $draft) { draft in
            HookEditorSheet(
                draft: draft,
                title: editingID == nil ? L("Add Hook") : L("Edit Hook"),
                onCancel: {
                    model.hooksEditing = false
                    self.draft = nil
                    editingID = nil
                },
                onSave: { saved in
                    commit(saved)
                    model.hooksEditing = false
                    self.draft = nil
                    editingID = nil
                })
        }
        .onAppear {
            model.helper.refresh()
            model.refreshSystemWakeState()
            model.refreshSyncedAutomations()
        }
        .onDisappear {
            model.hooksEditing = false
            copiedTask?.cancel()
            copied = nil
            draft = nil
            editingID = nil
        }
    }

    private func flash(_ value: Copied) {
        copiedTask?.cancel()
        copied = value
        copiedTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            copied = nil
        }
    }

    // MARK: Flow

    private var flowSteps: [AutomationFlow.Step] {
        let ready = model.wakeHelperGate == .ready
        let wake = model.wakeSchedule
        let wakeOn = ready && (wake?.isActive ?? false)
        let syncOn = ready && model.automationSyncConfig.enabled && !model.automationSyncConfig.enabledSources.isEmpty
        let wakeText: String
        if wakeOn, let wake {
            wakeText = wake.repeatingEnabled ? L("Every day at %@", wake.repeatTimeString) : L("Once, at a set time")
        } else if syncOn {
            wakeText = L("Before each AI run")
        } else {
            wakeText = ready ? L("No wake set") : L("Needs the helper")
        }
        let holdOn = (wakeOn && wake?.startSessionOnWake == true) || syncOn
        let holdText: String
        if wakeOn, let wake, wake.startSessionOnWake {
            holdText = wake.sessionDurationSeconds.map { L("For %@", SettingsFormat.short($0)) } ?? L("Until you stop it")
        } else if syncOn {
            holdText = L("%@ window", SettingsFormat.short(model.automationSyncConfig.holdSeconds))
        } else {
            holdText = L("Nothing held")
        }
        let leases = model.session.liveLeases.count
        let workText = !model.automationLeasesEnabled ? L("Leases off") : leases > 0 ? (leases == 1 ? L("1 lease") : L("%d leases", leases)) : L("Holds a lease")
        return [
            .init(anchor: "wake", symbol: "alarm", title: L("Wake"), detail: wakeText, live: wakeOn || syncOn),
            .init(anchor: "sync", symbol: "clock", title: L("Hold"), detail: holdText, live: holdOn),
            .init(anchor: "access", symbol: "sparkle", title: L("Agent works"), detail: workText, live: model.automationLeasesEnabled),
            .init(anchor: "endAction", symbol: endSymbol(model.endAction), title: L("Then"),
                  detail: model.endAction == .none ? L("Nothing happens") : model.endAction.label, live: model.endAction != .none),
        ]
    }

    // MARK: Agent access

    private var accessSection: some View {
        Section {
            ToggleRow(
                title: L("Allow automation leases"),
                subtitle: L("Let AI agents and scripts keep the Mac awake while work is running. It cannot wake a sleeping Mac."),
                symbol: "sparkle",
                isOn: Binding(get: { model.automationLeasesEnabled }, set: { model.automationLeasesEnabled = $0 }))
                .settingsAnchor("leases")
            if model.automationLeasesEnabled {
                if model.session.liveLeases.isEmpty {
                    Text(verbatim: L("No live leases right now."))
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.leading, 34)
                } else {
                    ForEach(model.session.liveLeases, id: \.id) { lease in
                        LabeledContent {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(verbatim: L("ends in %@", SettingsFormat.clock(lease.expiresAt.timeIntervalSince(context.date))))
                                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                SourceIcon(source: .agent(lease.owner), size: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(verbatim: lease.task.isEmpty ? AgentNames.displayName(lease.owner) : lease.task)
                                    Text(verbatim: "\(AgentNames.displayName(lease.owner)) · \(lease.tool)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.leading, 34)
                        }
                    }
                    HStack {
                        Spacer()
                        Button(model.session.liveLeases.count == 1 ? L("End Lease") : L("End All Leases")) {
                            model.endAutomationLeases()
                        }
                    }
                }
            }
            ToggleRow(
                title: L("Allow automation to change the wake schedule"),
                subtitle: L("Let trusted tools set or clear the Mac's scheduled wake. It needs the administrator helper and does not keep the Mac awake after it wakes."),
                symbol: "alarm",
                isOn: Binding(get: { model.automationWakeControlEnabled }, set: { model.automationWakeControlEnabled = $0 }))
            VStack(alignment: .leading, spacing: 8) {
                RowLabel(title: L("Connect an agent"), subtitle: L("Teach your agent to hold a lease for its own work."), symbol: "link")
                HStack(spacing: 8) {
                    Button(L("Copy Agent Instructions")) {
                        model.copyAgentInstructions()
                        flash(.access(L("Copied. Paste it to your agent in a new chat to teach it to manage Pervigil.")))
                    }
                    Menu(L("Copy MCP Setup")) {
                        Button(L("For Claude Code (JSON)")) { copyMCP(.mcpServersJSON) }
                        Button(L("For Gemini CLI (JSON)")) { copyMCP(.mcpServersJSON) }
                        Button(L("For Grok (JSON)")) { copyMCP(.mcpServersJSON) }
                        Button(L("For Codex (TOML)")) { copyMCP(.codexTOML) }
                        Divider()
                        Button(L("Server path only")) { copyMCP(.serverPath) }
                    }
                    .fixedSize()
                    Button(L("Reveal Skill Folder")) { model.revealAgentSkill() }
                        .buttonStyle(.link)
                }
                .controlSize(.small)
                .padding(.leading, 34)
                if case .access(let message) = copied {
                    RowNote(text: message, kind: .success)
                        .transition(.opacity)
                }
            }
            .settingsAnchor("connect")
        } header: {
            GroupHeader(L("Automation access"), info: L("A lease is a bounded keep-awake grant an outside tool asks for through the pervigil command line or the bundled MCP server: an AI agent working overnight, a render script, a backup job. Each lease has a time limit its owner must keep renewing, plus a hard seven day ceiling, so a crashed tool can never hold the Mac awake for good. The menu shows every live lease, Stop ends them all, and the Mac can sleep again after the last one finishes. Turning leases off ends any live lease. The wake schedule switch is separate and off by default because a scheduled wake is a system-wide change applied by the administrator helper: leave it off unless a tool you trust should plan wake-ups for you."))
                .id("access")
        }
    }

    private func copyMCP(_ format: AppModel.MCPSetupFormat) {
        model.copyMCPSetup(format)
        switch format {
        case .serverPath:
            flash(.access(L("Copied. Use it as the MCP server command in your agent's settings.")))
        case .mcpServersJSON, .codexTOML:
            flash(.access(L("Copied. Paste it into your agent's MCP configuration file.")))
        }
    }

    // MARK: Scheduled AI runs

    private var automationSyncSection: some View {
        Section {
            switch model.wakeHelperGate {
            case .ready:
                syncReadyContent
            case .needsHelper, .awaitingApproval, .helperUpdating:
                HelperLockedRow(model: model, context: .scheduledAIRuns)
                if !model.syncedAutomations.isEmpty {
                    Text("These local runs would be woken for once the helper is installed.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(model.syncedAutomations) { automation in
                        runRow(automation, sourceEnabled: false, preview: true)
                    }
                }
            }
        } header: {
            GroupHeader(L("Scheduled AI runs"), info: L("Pervigil reads the recurring tasks your local AI tools schedule (Claude Desktop local routines, Codex automations, tokenstat.ai automations), wakes the Mac a few minutes before each run, and holds it awake for a short window so the run is not skipped. It reads only the schedule and name, never the task's prompt. Cloud routines run on the vendor's servers even with the lid shut, so they are neither listed nor woken for. For a run longer than the window, have the agent hold a Pervigil lease (see the command line and MCP setup below) and the Mac stays awake until it releases."))
                .id("sync")
        } footer: {
            sectionFooter("Wake the Mac for local Claude Desktop, Codex, and tokenstat.ai tasks, then hold it awake while they run.")
        }
    }

    @ViewBuilder
    private var syncReadyContent: some View {
        ToggleRow(
            title: L("Wake for scheduled AI runs"),
            symbol: "calendar",
            isOn: Binding(get: { model.automationSyncConfig.enabled }, set: { on in
                var config = model.automationSyncConfig
                config.enabled = on
                model.automationSyncConfig = config
            }))
            .settingsAnchor("syncToggle")
        if model.automationSyncConfig.enabled {
            if model.syncedAutomations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar").font(.title2).foregroundStyle(.secondary)
                    Text("No local scheduled runs found").font(.callout.weight(.medium))
                    Text("Add one in Claude Desktop (Routines ▸ New routine ▸ Local), Codex (Scheduled tasks ▸ Create), or tokenstat.ai (Automations), then refresh. Cloud routines run on the vendor's servers and need no wake.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Refresh") { model.refreshSyncedAutomations() }.controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 8) {
                    RowNote(text: syncStatusText, kind: .info)
                    Spacer(minLength: 8)
                    Button("Refresh") { model.refreshSyncedAutomations() }.controlSize(.small)
                }
                if model.automationSyncConfig.enabledSources.isEmpty {
                    Text("Turn on a platform to wake for its runs. Left off, they stay listed but are never woken for.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(sourcesWithRuns, id: \.self) { source in
                    Toggle(isOn: Binding(
                        get: { model.isAutomationSourceEnabled(source) },
                        set: { on in model.setAutomationSourceEnabled(source, on) })) {
                        HStack(spacing: 10) {
                            SourceIcon(source: sourceIcon(source), size: 24)
                            Text(verbatim: source.label).font(.callout.weight(.semibold))
                        }
                    }
                    .toggleStyle(.switch)
                    ForEach(model.syncedAutomations.filter { $0.source == source }) { automation in
                        runRow(automation, sourceEnabled: model.isAutomationSourceEnabled(source), preview: false)
                    }
                }
                if let next = model.automationNextWakeTime {
                    LabeledContent {
                        Text(verbatim: Self.wakeStamp.string(from: next)).monospacedDigit().foregroundStyle(.secondary)
                    } label: {
                        RowLabel(title: L("Next wake"), symbol: "alarm", tint: .on)
                    }
                }
                LabeledContent {
                    Picker("", selection: Binding(get: { model.automationSyncConfig.holdSeconds }, set: { seconds in
                        var config = model.automationSyncConfig
                        config.holdSeconds = seconds
                        model.automationSyncConfig = config
                    })) {
                        ForEach([5, 15, 30, 60], id: \.self) { minutes in
                            Text(verbatim: SettingsFormat.short(TimeInterval(minutes * 60))).tag(TimeInterval(minutes * 60))
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                } label: {
                    RowLabel(title: L("Stay awake for"), subtitle: L("A fallback window around each run."), symbol: "clock")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("This window is a fallback. For a run that lasts longer, have the task's own agent hold a Pervigil lease for the whole session, so the Mac stays awake until the work is done, then sleeps.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !model.automationLeasesEnabled {
                        RowNote(text: L("Leases are off. Turn on \u{201C}Allow automation leases\u{201D} under Automation access for the agent's lease to hold."), kind: .warning, indented: false)
                    }
                    Button("Copy Run Instructions") {
                        model.copyAutomationRunInstructions()
                        flash(.runInstructions)
                    }
                    .controlSize(.small)
                    if copied == .runInstructions {
                        RowNote(text: L("Copied. Paste it into the scheduled task's prompt, so its agent holds the Mac awake for the run."), kind: .success, indented: false)
                            .transition(.opacity)
                    }
                }
                .padding(.leading, 34)
            }
        }
    }

    private func runRow(_ automation: ScheduledAutomation, sourceEnabled: Bool, preview: Bool) -> some View {
        let woken = sourceEnabled && automation.enabled && !model.isAutomationMuted(automation.id)
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: automation.name)
                Text(verbatim: runSubtitle(automation)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if sourceEnabled && !preview {
                Toggle("", isOn: Binding(
                    get: { !model.isAutomationMuted(automation.id) },
                    set: { on in model.setAutomationMuted(automation.id, !on) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(!automation.enabled)
                    .accessibilityLabel(Text(verbatim: automation.name))
            }
        }
        .padding(.leading, 34)
        .opacity(woken ? 1 : 0.5)
    }

    private var sourcesWithRuns: [ScheduledAutomation.Source] {
        var ordered: [ScheduledAutomation.Source] = []
        for automation in model.syncedAutomations where !ordered.contains(automation.source) {
            ordered.append(automation.source)
        }
        return ordered
    }

    private func sourceIcon(_ source: ScheduledAutomation.Source) -> TriggerSource {
        switch source.label.lowercased() {
        case let label where label.contains("claude"): return .agent("claude")
        case let label where label.contains("codex"): return .agent("codex")
        default: return .symbol("calendar")
        }
    }

    private var syncStatusText: String {
        guard let checked = model.automationsLastChecked else {
            return L("Scanning Claude Desktop, Codex, and tokenstat.ai")
        }
        return L("Scanning Claude Desktop, Codex, and tokenstat.ai · checked %@", Self.relativeChecked(checked))
    }

    private func runSubtitle(_ automation: ScheduledAutomation) -> String {
        guard automation.enabled else { return L("Paused in %@", automation.source.label) }
        guard let next = automation.recurrence.nextOccurrences(after: Date(), count: 1, calendar: .current).first else {
            return automation.source.label
        }
        return L("%@ · next %@", automation.source.label, Self.wakeStamp.string(from: next))
    }

    private static let wakeStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static func relativeChecked(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 45 { return L("just now") }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: Scheduled wake

    private var scheduledWakeSection: some View {
        Section {
            switch model.wakeHelperGate {
            case .ready:
                wakeEditor
            case .needsHelper, .awaitingApproval, .helperUpdating:
                if model.wakeSchedule != nil {
                    RowNote(text: L("A wake schedule is saved, but it is not active on this Mac until the administrator helper is ready. The system will not wake from this plan."), kind: .warning, indented: false)
                    Button("Turn Off Wake Schedule", role: .destructive) { model.wakeSchedule = nil }
                }
                HelperLockedRow(model: model, context: .wakeSchedule)
            }
        } header: {
            GroupHeader(L("Scheduled wake"), info: L("Wake the Mac at a set time through the administrator helper (pmset schedule / repeat), then optionally start a keep-awake session so it does not fall back asleep before the job runs. Pair with an end-of-session action above for wake, work, sleep. Scheduled wake is reliable on AC power. On battery the firmware may skip it. macOS only allows one system-wide repeating power schedule, so enabling ours replaces whatever was there. The controls stay locked until the helper is installed and ready, the same rule as the thermal fan boost."))
                .id("wake")
        } footer: {
            if model.wakeHelperGate == .ready {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Reliable on AC power. On battery the firmware may skip the wake."))
                    if !model.systemWakeState.scheduledWakes.isEmpty {
                        Text(L("Scheduled wakes on this Mac: %@", model.systemWakeState.scheduledWakes
                            .map { $0.formatted(date: .abbreviated, time: .shortened) }.joined(separator: ", ")))
                    }
                    if let repeating = model.systemWakeState.repeatingSummary {
                        Text(L("Repeating wake on this Mac: %@", repeating))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var wakeEditor: some View {
        ToggleRow(
            title: L("Wake schedule"),
            symbol: "alarm",
            isOn: Binding(get: { model.wakeSchedule != nil }, set: { on in
                model.wakeSchedule = on ? (model.wakeSchedule ?? WakeScheduleConfig()) : nil
            }))
            .settingsAnchor("wakeToggle")
        if model.wakeSchedule != nil {
            LabeledContent {
                HStack(spacing: 8) {
                    if model.wakeSchedule?.repeatingEnabled == true {
                        DatePicker("", selection: repeatTimeBinding, displayedComponents: [.hourAndMinute]).labelsHidden()
                    }
                    Toggle("", isOn: Binding(
                        get: { model.wakeSchedule?.repeatingEnabled ?? false },
                        set: { on in updateWake { $0.repeatingEnabled = on } }))
                        .labelsHidden().toggleStyle(.switch)
                        .accessibilityLabel(L("Repeat daily / weekly"))
                }
            } label: {
                RowLabel(title: L("Every day at"), subtitle: model.wakeSchedule?.repeatingEnabled == true
                         ? L("Uses every day (MTWRFSU). macOS allows only one system-wide repeating power schedule.") : nil, indented: true)
            }
            LabeledContent {
                HStack(spacing: 8) {
                    if model.wakeSchedule?.oneShot != nil {
                        DatePicker("", selection: Binding(
                            get: { model.wakeSchedule?.oneShot ?? Date() },
                            set: { date in updateWake { $0.oneShot = date } }),
                            displayedComponents: [.date, .hourAndMinute]).labelsHidden()
                    }
                    Toggle("", isOn: Binding(
                        get: { model.wakeSchedule?.oneShot != nil },
                        set: { on in updateWake { $0.oneShot = on ? ($0.oneShot ?? Date().addingTimeInterval(3600)) : nil } }))
                        .labelsHidden().toggleStyle(.switch)
                        .accessibilityLabel(L("One-shot wake"))
                }
            } label: {
                RowLabel(title: L("Once, at"), indented: true)
            }
            LabeledContent {
                HStack(spacing: 8) {
                    if model.wakeSchedule?.startSessionOnWake == true {
                        Picker("", selection: Binding(
                            get: { model.wakeSchedule?.sessionDurationSeconds ?? 0 },
                            set: { value in updateWake { $0.sessionDurationSeconds = value > 0 ? value : nil } })) {
                            Text(L("Indefinite")).tag(TimeInterval(0))
                            Text(L("30 minutes")).tag(30 * 60 as TimeInterval)
                            Text(L("1 hour")).tag(60 * 60 as TimeInterval)
                            Text(L("2 hours")).tag(2 * 60 * 60 as TimeInterval)
                            Text(L("4 hours")).tag(4 * 60 * 60 as TimeInterval)
                        }
                        .labelsHidden().fixedSize()
                        .accessibilityLabel(L("Session length"))
                    }
                    Toggle("", isOn: Binding(
                        get: { model.wakeSchedule?.startSessionOnWake ?? true },
                        set: { on in updateWake { $0.startSessionOnWake = on } }))
                        .labelsHidden().toggleStyle(.switch)
                        .accessibilityLabel(L("Start keep-awake on wake"))
                }
            } label: {
                RowLabel(title: L("Start keep-awake on wake"), subtitle: model.wakeSchedule?.startSessionOnWake == true
                         ? L("When the Mac wakes near this schedule, Pervigil starts a session so it does not fall back asleep. Works best with triggers off for that window, or with a trigger that stays satisfied.") : nil,
                         indented: true)
            }
            if model.wakeSchedule?.isActive != true {
                RowNote(text: L("Turn on a one-shot time, a repeating time, or both. With neither, nothing is installed on the system."))
            }
        }
    }

    private var repeatTimeBinding: Binding<Date> {
        Binding(
            get: {
                // Wall-clock components on both sides, never elapsed time since
                // midnight: on a DST day the two differ, and pmset takes wall time.
                let secs = model.wakeSchedule?.repeatSecondsFromMidnight ?? 0
                let calendar = Calendar.current
                return calendar.date(bySettingHour: secs / 3600, minute: (secs % 3600) / 60, second: secs % 60,
                                     of: calendar.startOfDay(for: Date())) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                updateWake { $0.repeatSecondsFromMidnight = (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 }
            })
    }

    private func updateWake(_ body: (inout WakeScheduleConfig) -> Void) {
        guard var config = model.wakeSchedule else { return }
        body(&config)
        model.wakeSchedule = config
    }

    // MARK: After the session ends

    private var endActionSection: some View {
        Section {
            HStack(alignment: .top, spacing: 8) {
                ForEach(SessionEndAction.allCases, id: \.self) { action in
                    PictureChoice(
                        value: action,
                        selection: Binding(get: { model.endAction }, set: { model.endAction = $0 }),
                        title: action.label,
                        centered: true
                    ) {
                        Image(systemName: endSymbol(action)).font(.system(size: 20, weight: .light))
                    }
                }
            }
            .padding(.vertical, 2)
            .settingsAnchor("endChoices")
            if let note = endActionNote {
                RowNote(text: note.text, kind: note.kind, indented: false)
            }
        } header: {
            GroupHeader(L("After the session ends"), info: L("When the last thing keeping the Mac awake ends on its own (a timer expiring, trigger conditions dropping, or the final automation lease releasing), Pervigil can put the display to sleep, lock the screen, start the screen saver, or sleep the Mac. Leases count: while any lease is live the session continues and nothing fires. Off by default so a timed session never surprises you. Manual stops, and the battery and thermal safety pauses, never run this action. A brief debounce cancels it if the session restarts right away."))
                .id("endAction")
        } footer: {
            sectionFooter("Fires a few seconds after a natural end, not on a manual stop or a safety pause.")
        }
    }

    private func endSymbol(_ action: SessionEndAction) -> String {
        switch action {
        case .none: "circle.slash"
        case .sleepDisplay: "display"
        case .lockScreen: "lock.display"
        case .startScreensaver: "sparkles.tv"
        case .sleepMac: "moon.zzz"
        }
    }

    private var endActionNote: (text: String, kind: RowNote.Kind)? {
        switch model.endAction {
        case .none, .sleepDisplay, .startScreensaver:
            return nil
        case .lockScreen:
            return (L("Locks via System Events. macOS may ask once for Automation access for Pervigil."), .info)
        case .sleepMac:
            if model.helperInstalled && !model.helper.daemonOutdated && !model.helper.awaitingApproval {
                return (L("Sleeps the Mac through the administrator helper (instant, no extra prompts)."), .success)
            }
            if model.helper.awaitingApproval {
                return (L("The helper is waiting for approval in System Settings. Until then, sleep falls back to System Events, which may ask for Automation access once."), .info)
            }
            if model.helper.daemonOutdated {
                return (L("The helper is updating itself. Until that finishes, sleep falls back to System Events, which may ask for Automation access once."), .info)
            }
            return (L("Without the administrator helper, sleep uses System Events and may ask for Automation access once. Install the helper under Preferences ▸ General for instant, silent sleep."), .info)
        }
    }

    // MARK: Event hooks

    private var eventHooksSection: some View {
        Section {
            if model.eventHooks.isEmpty {
                Text(L("No event hooks yet.")).foregroundStyle(.secondary)
            } else {
                ForEach(model.eventHooks) { hook in
                    Toggle(isOn: Binding(
                        get: { hook.enabled },
                        set: { enabled in
                            var hooks = model.eventHooks
                            if let i = hooks.firstIndex(where: { $0.id == hook.id }) {
                                hooks[i].enabled = enabled
                                model.eventHooks = hooks
                            }
                        })) {
                        HStack(spacing: 10) {
                            StateIcon(symbol: hookSymbol(hook.action), tint: hook.enabled ? .on : .neutral)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hook.event.label)
                                Text(hook.action.label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Button { beginEdit(hook) } label: { Image(systemName: "pencil") }
                                .buttonStyle(.borderless)
                                .help(L("Edit hook"))
                        }
                    }
                    .toggleStyle(.switch)
                }
                .onDelete(perform: deleteHooks)
            }
        } header: {
            HStack(spacing: 4) {
                Text(verbatim: L("Event hooks"))
                InfoButton(text: L("When something happens in Pervigil, run a Shortcut, POST a webhook, or run a shell command. Useful for a push to your phone when an overnight agent finishes (ntfy, or a Shortcut that sends a notification). Hooks are suspended while you edit them, so a half-written command never runs. No administrator helper needed. User-authored shell commands are intentional in this unsandboxed app: only add commands you trust."))
                Spacer()
                Button { beginAdd() } label: { Label(L("Add Hook…"), systemImage: "plus") }
                    .buttonStyle(.borderless)
            }
            .textCase(nil)
            .id("hooks")
        } footer: {
            sectionFooter("Run a Shortcut, post a webhook, or a shell command on session and trigger events. No helper required.")
        }
    }

    private func hookSymbol(_ action: HookAction) -> String {
        switch action {
        case .runShortcut: "square.2.layers.3d"
        case .webhook: "globe"
        case .shell: "terminal"
        }
    }

    private func beginAdd() {
        model.hooksEditing = true
        editingID = nil
        draft = HookDraft(event: .sessionEnded, kind: .shortcut, shortcutName: "", webhookURL: "", shellCommand: "")
    }

    private func beginEdit(_ hook: EventHook) {
        model.hooksEditing = true
        editingID = hook.id
        draft = HookDraft(from: hook)
    }

    private func commit(_ draft: HookDraft) {
        guard let action = draft.action else { return }
        var hooks = model.eventHooks
        if let id = editingID, let i = hooks.firstIndex(where: { $0.id == id }) {
            hooks[i].event = draft.event
            hooks[i].action = action
        } else {
            hooks.append(EventHook(event: draft.event, action: action))
        }
        model.eventHooks = hooks
    }

    private func deleteHooks(at offsets: IndexSet) {
        var hooks = model.eventHooks
        hooks.remove(atOffsets: offsets)
        model.eventHooks = hooks
    }
}

// MARK: - Flow

/// Wake, Hold, Agent works, Then: four steps that light up as the settings
/// below make them happen. Each jumps to its section.
private struct AutomationFlow: View {
    struct Step { let anchor: String; let symbol: String; let title: String; let detail: String; let live: Bool }
    let steps: [Step]
    let jump: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                Button { jump(step.anchor) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: step.symbol)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(step.live ? Color.white : Color.secondary)
                            .frame(width: 36, height: 36)
                            .background(step.live ? Color.panelAccentSolid : Color.primary.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(verbatim: step.title)
                            .font(.system(size: 12, weight: step.live ? .semibold : .medium))
                            .foregroundStyle(step.live ? .primary : .secondary)
                        Text(verbatim: step.detail)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topLeading) {
                    if index > 0 {
                        Capsule()
                            .fill(step.live && steps[index - 1].live ? Color.panelAccentSolid.opacity(0.35) : Color.primary.opacity(0.1))
                            .frame(height: 2)
                            .padding(.horizontal, 0)
                            .frame(width: 70)
                            .offset(x: -35, y: 23)
                    }
                }
                .accessibilityLabel(Text(verbatim: "\(step.title): \(step.detail)"))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Hook editor

/// Editable fields for one hook, independent of the live settings list.
struct HookDraft: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case shortcut, webhook, shell
        var id: String { rawValue }
        /// Short enough for a three-way segmented control without clipping.
        var label: String {
            switch self {
            case .shortcut: return L("Shortcut")
            case .webhook: return L("Webhook")
            case .shell: return L("Shell")
            }
        }
    }

    let id = UUID()
    var event: HookEvent
    var kind: Kind
    var shortcutName: String
    var webhookURL: String
    var shellCommand: String

    init(event: HookEvent, kind: Kind, shortcutName: String, webhookURL: String, shellCommand: String) {
        self.event = event
        self.kind = kind
        self.shortcutName = shortcutName
        self.webhookURL = webhookURL
        self.shellCommand = shellCommand
    }

    init(from hook: EventHook) {
        self.event = hook.event
        self.shortcutName = ""
        self.webhookURL = ""
        self.shellCommand = ""
        switch hook.action {
        case .runShortcut(let name): self.kind = .shortcut; self.shortcutName = name
        case .webhook(let url): self.kind = .webhook; self.webhookURL = url
        case .shell(let command): self.kind = .shell; self.shellCommand = command
        }
    }

    var action: HookAction? {
        switch kind {
        case .shortcut:
            let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : .runShortcut(name: name)
        case .webhook:
            let url = webhookURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return url.isEmpty ? nil : .webhook(url: url)
        case .shell:
            let command = shellCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            return command.isEmpty ? nil : .shell(command: command)
        }
    }
}

private struct HookEditorSheet: View {
    @State var draft: HookDraft
    let title: String
    let onCancel: () -> Void
    let onSave: (HookDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(L("Hooks are paused while you edit, so a half-written command never runs."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Form {
                Picker("When", selection: $draft.event) {
                    ForEach(HookEvent.allCases, id: \.self) { event in
                        Text(event.label).tag(event)
                    }
                }
                // Short labels only: longer ones clip in a three-way segment.
                Picker("Do", selection: $draft.kind) {
                    ForEach(HookDraft.Kind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                switch draft.kind {
                case .shortcut:
                    TextField("Shortcut name", text: $draft.shortcutName).textFieldStyle(.roundedBorder)
                case .webhook:
                    TextField("https://…", text: $draft.webhookURL).textFieldStyle(.roundedBorder)
                case .shell:
                    TextField("/bin/sh -c …", text: $draft.shellCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    RowNote(text: L("Runs as you, with your permissions. Only add commands you trust."), kind: .warning, indented: false)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save") { onSave(draft) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.action == nil)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
