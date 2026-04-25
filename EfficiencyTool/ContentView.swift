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

    var body: some View {
        HStack(spacing: 4) {
            phaseIcon
            phaseLabel
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.secondary.opacity(0.1), in: Capsule())
        .animation(.easeInOut(duration: 0.2), value: phase.isBusy)
    }

    @ViewBuilder private var phaseIcon: some View {
        if phase.isBusy {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 10, height: 10)
        } else if case .sleeping = phase {
            Image(systemName: "clock").font(.system(size: 9))
        }
    }

    @ViewBuilder private var phaseLabel: some View {
        switch phase {
        case .idle:    EmptyView()
        case .starting: Text("Starting…")
        case .scanning: Text("Scanning…")
        case .sleeping:
            HStack(spacing: 2) {
                Text("Next in")
                Text("\(countdown)s")
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.linear(duration: 0.4), value: countdown)
            }
        }
    }
}

// MARK: - CoreDot

private struct CoreDot: View {
    let assignment: CoreAssignment
    @State private var scale: CGFloat = 1

    var body: some View {
        Circle()
            .fill(assignment.color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.3), value: assignment)
            .onChange(of: assignment) { _, _ in
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) { scale = 1.7 }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55).delay(0.12)) { scale = 1 }
            }
    }
}

// MARK: - AllocationState

// Drives gradient color selection in CardGradientLayer.
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

// MARK: - CardGradientLayer

// Soft animated gradient rendered as a .background() inside a card's content area.
// Uses two independent animations:
//   • shift  – repeating 3s easeInOut that rotates the gradient diagonal (always running)
//   • fade   – 0.65s easeInOut triggered by allocationState changes (cross-fades colors)
private struct CardGradientLayer: View {
    let allocationState: AllocationState

    @State private var shift = false
    // Separate rendered state so color cross-fades are isolated from the shift animation
    @State private var renderedState: AllocationState = .idle
    @State private var layerOpacity: Double = 0

    var body: some View {
        LinearGradient(
            colors: colors(for: renderedState),
            startPoint: shift ? .topLeading  : .topTrailing,
            endPoint:   shift ? .bottomTrailing : .bottomLeading
        )
        .opacity(layerOpacity)
        .onAppear {
            // Snap to initial state without animating
            renderedState = allocationState
            layerOpacity  = allocationState != .idle ? 1 : 0
            startShift()
        }
        .onChange(of: allocationState) { _, new in
            // Cross-fade colors and opacity together
            withAnimation(.easeInOut(duration: 0.65)) {
                renderedState = new
                layerOpacity  = new != .idle ? 1 : 0
            }
        }
    }

    private func startShift() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            shift.toggle()
        }
    }

    private func colors(for state: AllocationState) -> [Color] {
        switch state {
        case .idle:
            return [.clear, .clear]
        case .active:
            return [Color.blue.opacity(0.16), Color.indigo.opacity(0.10), .clear]
        case .efficiency:
            return [Color.blue.opacity(0.20), Color.blue.opacity(0.08), .clear]
        case .performance:
            return [Color.orange.opacity(0.20), Color.orange.opacity(0.08), .clear]
        case .mixed:
            return [Color.blue.opacity(0.16), Color.purple.opacity(0.08), Color.orange.opacity(0.16)]
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

    private let radius: CGFloat = 11

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
            HStack(spacing: 0) {
                Label(title, systemImage: icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Content – each card manages its own inner padding
            content
        }
        // Fill first, then clip all children (including inner backgrounds) to the rounded rect.
        // Shadow applied after clip so it traces the card outline, not the inner content.
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 0.5)
        )
        // Two-layer shadow: diffuse outer + crisp contact shadow
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 4)
        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
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
            HStack(spacing: 8) {
                chipList
                Spacer(minLength: 0)
                Divider().frame(height: 18)
                TextField(language.new_rule, text: $config.newCustomPattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit(addKeyword)
                Button(language.add, action: addKeyword)
                    .disabled(config.newCustomPattern
                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var chipList: some View {
        if config.getCustomPatterns().isEmpty {
            Text("No custom keywords — using defaults")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(config.getCustomPatterns(), id: \.self) { kw in
                        HStack(spacing: 3) {
                            Text(kw).font(.caption)
                            Button {
                                var p = config.getCustomPatterns()
                                p.removeAll { $0 == kw }
                                config.setCustomPatterns(p)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .semibold))
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.12), in: Capsule())
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
    @State private var selection: Set<Int> = []

    var body: some View {
        CardView(icon: "cpu", title: "Active Processes") {
            countBadge
        } content: {
            Group {
                if config.assignedProcesses.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else {
                    table
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: config.assignedProcesses.isEmpty)
            .background(
                CardGradientLayer(
                    allocationState: AllocationState.from(
                        config.assignedProcesses,
                        running: config.isRunning
                    )
                )
            )
        }
    }

    // Trailing badge in the card header
    private var countBadge: some View {
        Group {
            if !config.assignedProcesses.isEmpty {
                Text("\(config.assignedProcesses.count)")
                    .font(.caption2)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)
                    .animation(.easeOut(duration: 0.2), value: config.assignedProcesses.count)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Group {
                if config.scriptPhase.isBusy {
                    Image(systemName: "hourglass")
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                } else {
                    Image(systemName: "cpu")
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                }
            }
            .font(.system(size: 26))
            .foregroundStyle(.tertiary)
            .animation(.easeInOut(duration: 0.25), value: config.scriptPhase.isBusy)

            Text(config.scriptPhase.isBusy
                 ? "Waiting for processes to be assigned…"
                 : "Start the script to begin tracking processes")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: config.scriptPhase.isBusy)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.vertical, 16)
    }

    private var table: some View {
        Table(config.assignedProcesses, selection: $selection) {
            TableColumn("") { p in
                CoreDot(assignment: p.coreAssignment)
            }
            .width(16)

            TableColumn("Process") { p in
                Text(p.name).lineLimit(1).truncationMode(.middle)
            }

            TableColumn("PID") { p in
                Text(String(p.id))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(64)

            TableColumn("Core") { p in
                Label(p.coreAssignment.label, systemImage: p.coreAssignment.symbolName)
                    .font(.caption)
                    .foregroundStyle(p.coreAssignment.color)
            }
            .width(110)
        }
        .frame(minHeight: 120, maxHeight: 260)
    }
}

// MARK: - CoreAllocationCard

struct CoreAllocationCard: View {
    @ObservedObject private var config   = AppStorageConfig.config
    @ObservedObject private var language = Language.config

    var body: some View {
        CardView(icon: "slider.horizontal.3", title: language.advanced_setting) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(language.global_search, isOn: $config.useAltPSCommand)
                    .help(config.altPSWarning)
                Toggle(language.use_focus_check,          isOn: $config.enableFocusCheck)
                Toggle(language.use_balance_mode,         isOn: $config.enableBalanceCheck)
                Toggle(language.use_default_rules,        isOn: $config.enableDefaultRules)
                Toggle(language.reverse_performance_core, isOn: $config.enablePerformanceCore)
                Toggle("Detect Power Adapter Mode",       isOn: $config.isDetectingPower)
            }
            .padding(14)
            .background(
                CardGradientLayer(allocationState: config.isRunning ? .active : .idle)
            )
        }
    }
}

// MARK: - BalanceSettingsCard

struct BalanceSettingsCard: View {
    @ObservedObject private var config   = AppStorageConfig.config
    @ObservedObject private var language = Language.config

    var body: some View {
        CardView(icon: "gauge.medium", title: language.balance_settings) {
            VStack(spacing: 10) {
                LabeledContent(language.check_threshold) {
                    TextField("", text: $config.BalanceThreshold)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(language.send_threshold) {
                    TextField("", text: $config.CPUThreshold)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(14)
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
                    .padding(12)
                }
                .frame(minHeight: 160)
                .onChange(of: config.output) { _, _ in
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
            .background(Color.black.opacity(0.22))
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject private var config   = AppStorageConfig.config
    @ObservedObject private var runner   = ScriptRunner.shared
    @ObservedObject private var language = Language.config

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    KeywordFiltersCard()
                    ProcessTableCard()
                    HStack(alignment: .top, spacing: 16) {
                        CoreAllocationCard()
                        BalanceSettingsCard()
                    }
                    runStopButton
                    ConsoleCard()
                }
                .padding(20)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.22, blue: 0.48),
                    Color(red: 0.20, green: 0.16, blue: 0.38),
                    Color(red: 0.13, green: 0.10, blue: 0.27)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .colorScheme(.dark)
        .frame(minWidth: 560, minHeight: 650)
    }

    // MARK: – Header bar

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "speedometer")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Efficiency Tool")
                .font(.headline)

            Spacer()

            if config.isRunning {
                PhaseIndicatorView(phase: config.scriptPhase, countdown: config.sleepCountdown)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Circle()
                .fill(config.isRunning ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)

            Text(config.isRunning ? "Running" : "Idle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.25), value: config.isRunning)
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
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderedProminent)
        .tint(config.isRunning ? Color(red: 0.85, green: 0.2, blue: 0.3) : Color(red: 0.45, green: 0.32, blue: 0.80))
        .controlSize(.large)
        .keyboardShortcut(.return)
        .shadow(
            color: (config.isRunning ? Color.red : Color(red: 0.55, green: 0.40, blue: 0.95)).opacity(0.5),
            radius: 14, x: 0, y: 0
        )
        .animation(.easeInOut(duration: 0.2), value: config.isRunning)
    }
}
