import SwiftUI

// MARK: - VisualEffectView

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - PhaseIndicatorView

private struct PhaseIndicatorView: View {
    let phase: ScriptPhase
    let countdown: Int
    @ObservedObject private var language = Language.config
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            phaseIcon
            phaseLabel
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
        .overlay(Capsule().stroke(.quaternary, lineWidth: 0.5))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: phase.isBusy)
    }

    @ViewBuilder private var phaseIcon: some View {
        if phase.isBusy {
            if reduceMotion {
                Image(systemName: "circle.dotted")
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
            }
        } else if case .sleeping = phase {
            Image(systemName: "clock")
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var phaseLabel: some View {
        switch phase {
        case .idle:    EmptyView()
        case .starting: Text(language.starting)
        case .scanning: Text(language.scanning)
        case .sleeping:
            HStack(spacing: 2) {
                Text(language.next_in)
                Text("\(countdown)\(language.seconds_suffix)")
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                    .animation(reduceMotion ? nil : .linear(duration: 0.4), value: countdown)
            }
        }
    }
}

// MARK: - CoreDot

private struct CoreDot: View {
    let assignment: CoreAssignment
    @State private var scale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(assignment.color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: assignment)
            .accessibilityHidden(true)
            .onChange(of: assignment) { _, _ in
                guard !reduceMotion else {
                    scale = 1
                    return
                }
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) { scale = 1.7 }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55).delay(0.12)) { scale = 1 }
            }
    }
}

// MARK: - AllocationState

// Drives the compact process-status badge.
// Computed from assignedProcesses + isRunning — never stored in AppStorageConfig.
private enum AllocationState: Equatable {
    case idle
    case active        // script running, no per-process data yet (CoreAllocationCard)
    case efficiency    // all tracked processes on efficiency cores
    case performance   // all tracked processes on performance cores
    case mixed         // split between efficiency and performance

    static func from(_ processes: [TrackedProcess], running: Bool) -> Self {
        guard running else { return .idle }
        guard !processes.isEmpty else { return .active }
        let hasEff  = processes.contains { $0.coreAssignment == .efficiency }
        let hasPerf = processes.contains { $0.coreAssignment == .performance }
        switch (hasEff, hasPerf) {
        case (true, false): return .efficiency
        case (false, true): return .performance
        default:            return .mixed
        }
    }
}

private extension AllocationState {
    var label: String {
        switch self {
        case .idle: return "Idle"
        case .active: return "Monitoring"
        case .efficiency: return "Efficiency"
        case .performance: return "Performance"
        case .mixed: return "Mixed"
        }
    }

    var accent: Color {
        switch self {
        case .idle: return .secondary
        case .active, .efficiency: return .blue
        case .performance: return .orange
        case .mixed: return .purple
        }
    }
}

// MARK: - CardView

// Generic floating card container used by every module.
// Provides the rounded-rect background, drop shadow, border, and a labelled header row.
struct CardView<Trailing: View, Content: View>: View {
    let icon: String
    let title: String
    let trailing: Trailing
    let content: Content

    private let radius: CGFloat = 14

    init(
        icon: String,
        title: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().opacity(0.65)

            // Content – each card manages its own inner padding
            content
        }
        // Fill first, then clip all children (including inner backgrounds) to the rounded rect.
        // Shadow applied after clip so it traces the card outline, not the inner content.
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.primary.opacity(0.10), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }
}

extension CardView where Trailing == EmptyView {
    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.init(icon: icon, title: title, trailing: { EmptyView() }, content: content)
    }
}

// MARK: - KeywordFiltersCard

struct KeywordFiltersCard: View {
    @ObservedObject private var config   = AppStorageConfig.config
    @ObservedObject private var language = Language.config

    var body: some View {
        CardView(icon: "tag", title: language.customize_rules) {
            VStack(alignment: .leading, spacing: 12) {
                chipList
                    .frame(maxWidth: .infinity, alignment: .leading)

                if config.enableDefaultRules {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .accessibilityHidden(true)
                        Text(language.default_rules_caption)
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help(language.help_default_rules)
                }

                HStack(spacing: 10) {
                    TextField(language.new_rule, text: $config.newCustomPattern)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .onSubmit(addKeyword)

                    Button(language.add, action: addKeyword)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(config.newCustomPattern
                            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var chipList: some View {
        if config.getCustomPatterns().isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .accessibilityHidden(true)
                Text(language.no_custom_keywords)
            }
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(config.getCustomPatterns(), id: \.self) { kw in
                        HStack(spacing: 3) {
                            Text(kw)
                                .font(.caption)
                                .lineLimit(1)
                            Button {
                                var p = config.getCustomPatterns()
                                p.removeAll { $0 == kw }
                                config.setCustomPatterns(p)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .semibold))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(String(format: language.remove_keyword, kw))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .overlay(Capsule().stroke(.quaternary, lineWidth: 0.5))
                    }
                }
            }
        }
    }

    private func addKeyword() {
        let trimmed = config.newCustomPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        var current = config.getCustomPatterns()
        guard !trimmed.isEmpty, !current.contains(trimmed) else { return }
        current.append(trimmed)
        config.setCustomPatterns(current)
        config.newCustomPattern = ""
    }
}

// MARK: - ProcessTableCard

struct ProcessTableCard: View {
    @ObservedObject private var config = AppStorageConfig.config
    @ObservedObject private var language = Language.config
    @State private var selection: Set<Int> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CardView(icon: "cpu", title: language.active_processes) {
            HStack(spacing: 8) {
                statusBadge
                countBadge
            }
        } content: {
            Group {
                if config.assignedProcesses.isEmpty {
                    emptyState
                        .transition(reduceMotion ? .identity : .opacity)
                } else {
                    table
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: config.assignedProcesses.isEmpty)
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = nil
                }
            }
        }
    }

    private var allocationState: AllocationState {
        AllocationState.from(config.assignedProcesses, running: config.isRunning)
    }

    private var statusBadge: some View {
        Text(localizedAllocationLabel)
            .font(.caption2.weight(.medium))
            .foregroundStyle(allocationState.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(allocationState.accent.opacity(0.10), in: Capsule())
    }

    private var localizedAllocationLabel: String {
        switch allocationState {
        case .idle: return language.idle
        case .active: return language.monitoring
        case .efficiency: return language.efficiency
        case .performance: return language.performance
        case .mixed: return language.mixed
        }
    }

    // Trailing badge in the card header
    private var countBadge: some View {
        Group {
            if !config.assignedProcesses.isEmpty {
                Text("\(config.assignedProcesses.count)")
                    .font(.caption2)
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                    .foregroundStyle(.secondary)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: config.assignedProcesses.count)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Group {
                if config.scriptPhase.isBusy {
                    Image(systemName: "hourglass")
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.7)))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "cpu")
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.7)))
                        .accessibilityHidden(true)
                }
            }
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(.tertiary)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: config.scriptPhase.isBusy)

            Text(config.scriptPhase.isBusy
                 ? language.waiting_for_processes
                 : language.start_tracking_processes)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .contentTransition(reduceMotion ? .identity : .opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: config.scriptPhase.isBusy)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var table: some View {
        Table(config.assignedProcesses, selection: $selection) {
            TableColumn("") { p in
                CoreDot(assignment: p.coreAssignment)
            }
            .width(22)

            TableColumn(language.process) { p in
                Text(p.name).lineLimit(1).truncationMode(.middle)
            }

            TableColumn(language.pid) { p in
                Text(String(p.id))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(64)

            TableColumn(language.core) { p in
                HStack(spacing: 5) {
                    Image(systemName: p.coreAssignment.symbolName)
                        .accessibilityHidden(true)
                    Text(p.coreAssignment == .efficiency ? language.efficiency : language.performance)
                }
                .font(.caption)
                .foregroundStyle(p.coreAssignment.color)
            }
            .width(122)
        }
        .frame(minHeight: 148, idealHeight: 188, maxHeight: 280)
    }
}

// MARK: - CoreAllocationCard

struct CoreAllocationCard: View {
    @ObservedObject private var config   = AppStorageConfig.config
    @ObservedObject private var language = Language.config

    var body: some View {
        CardView(icon: "slider.horizontal.3", title: language.advanced_setting) {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(language.global_search, isOn: $config.useAltPSCommand)
                    .help(config.altPSWarning + " " + language.help_global_search)
                Toggle(language.use_focus_check,          isOn: $config.enableFocusCheck)
                    .help(language.help_focus_check)
                Toggle(language.use_balance_mode,         isOn: $config.enableBalanceCheck)
                    .help(language.help_balance_mode)
                Toggle(language.use_default_rules,        isOn: $config.enableDefaultRules)
                    .help(language.help_default_rules)
                Toggle(language.reverse_performance_core, isOn: $config.enablePerformanceCore)
                    .help(language.help_performance_core)
                Toggle(language.power_adapter_mode,       isOn: $config.isDetectingPower)
                    .help(language.help_power_adapter)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}

// MARK: - BalanceSettingsCard

struct BalanceSettingsCard: View {
    @ObservedObject private var config   = AppStorageConfig.config
    @ObservedObject private var language = Language.config
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CardView(icon: "gauge.medium", title: language.balance_settings) {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent(language.check_threshold) {
                    TextField("", text: $config.BalanceThreshold)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                .help(language.help_check_threshold)
                LabeledContent(language.send_threshold) {
                    TextField("", text: $config.CPUThreshold)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                .help(language.help_send_threshold)
                Divider()
                Toggle(language.fps_check_label, isOn: $config.enableFPSCheck)
                    .help(language.help_fps_check)
                if config.enableFPSCheck {
                    LabeledContent(language.fps_threshold_label) {
                        TextField("", text: $config.fpsVarianceThreshold)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                    .help(language.help_fps_threshold)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: config.enableFPSCheck)
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = nil
                }
            }
        }
    }
}

// MARK: - ConsoleCard

struct ConsoleCard: View {
    @ObservedObject private var config   = AppStorageConfig.config
    @ObservedObject private var language = Language.config

    var body: some View {
        CardView(icon: "terminal", title: language.console_output) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(config.output)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("end")
                        Text(language.end_script_help)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }
                    .padding(16)
                }
                .frame(minHeight: 172, idealHeight: 210, maxHeight: 280)
                .onChange(of: config.output) { _, _ in
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
            .background(Color.black.opacity(0.10))
            .textSelection(.enabled)
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject private var config   = AppStorageConfig.config
    @ObservedObject private var runner   = ScriptRunner.shared
    @ObservedObject private var language = Language.config
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().opacity(0.7)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ProcessPickerCard()
                        KeywordFiltersCard()
                        ProcessTableCard()

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                CoreAllocationCard()
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                BalanceSettingsCard()
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            VStack(alignment: .leading, spacing: 16) {
                                CoreAllocationCard()
                                BalanceSettingsCard()
                            }
                        }

                        runStopButton
                        ConsoleCard()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }

    // MARK: – Header bar

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "speedometer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            Text("Efficiency Tool")
                .font(.headline)
                .foregroundStyle(.primary)

            Picker("", selection: $config.useSimpleMode) {
                Text(language.mode_easy).tag(true)
                Text(language.mode_pro).tag(false)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .labelsHidden()
            .frame(width: 118)
            .onChange(of: config.useSimpleMode) { _, easy in
                language.setProMode(!easy)
            }
            .help(language.help_mode)

            Spacer()

            if config.isRunning {
                PhaseIndicatorView(phase: config.scriptPhase, countdown: config.sleepCountdown)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .trailing)))
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(config.isRunning ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)

                Text(config.isRunning ? language.running : language.idle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(reduceMotion ? .identity : .opacity)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(config.isRunning ? language.running : language.idle)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: config.isRunning)
    }

    // MARK: – Run / Stop button

    private var runStopButton: some View {
        Button {
            config.isRunning ? runner.stop() : runner.start()
            NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
        } label: {
            Label(
                config.isRunning ? language.stop_script : language.run_script,
                systemImage: config.isRunning ? "stop.fill" : "play.fill"
            )
            .frame(maxWidth: .infinity)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }
        .buttonStyle(.borderedProminent)
        .tint(config.isRunning ? .red : .accentColor)
        .controlSize(.large)
        .keyboardShortcut(.return)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: config.isRunning)
    }
}
