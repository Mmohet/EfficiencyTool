import SwiftUI

// MARK: - Process model

enum CoreAssignment: String, Equatable {
    case efficiency
    case performance

    var color: Color {
        switch self {
        case .efficiency:  return Color(nsColor: .systemBlue)
        case .performance: return Color(nsColor: .systemOrange)
        }
    }

    var label: String {
        switch self {
        case .efficiency:  return "Efficiency"
        case .performance: return "Performance"
        }
    }

    var symbolName: String {
        switch self {
        case .efficiency:  return "bolt.slash.fill"
        case .performance: return "bolt.fill"
        }
    }
}

struct TrackedProcess: Identifiable {
    let id: Int         // PID
    let name: String
    var coreAssignment: CoreAssignment
}

// MARK: - Script phase

// Derived entirely from stdout — never set manually except on start/stop boundaries.
enum ScriptPhase: Equatable {
    case idle
    case starting               // running, awaiting first loop tick
    case scanning               // timestamp fired, PID loop active
    case sleeping(Int)          // between loops; associated value = seconds remaining

    // True when the bash script is actively doing work (show spinner)
    var isBusy: Bool {
        switch self {
        case .scanning, .starting: return true
        default: return false
        }
    }
}

// MARK: - Config

class AppStorageConfig: ObservableObject {
    public static var config = AppStorageConfig()

    @AppStorage("customPatterns") public var customPatternsString: String = ""
    /// 易用模式（true）/ 专业模式（false）。易用模式隐藏高级选项、使用大白话文案。
    @AppStorage("useSimpleMode") public var useSimpleMode: Bool = true

    func getCustomPatterns() -> [String] {
        customPatternsString.isEmpty ? [] : customPatternsString.components(separatedBy: ",")
    }

    func setCustomPatterns(_ patterns: [String]) {
        customPatternsString = patterns.joined(separator: ",")
    }

    @Published public var newCustomPattern: String = ""

    @Published public var useAltPSCommand: Bool = false
    public let altPSWarning = "⚠️ 危险选项：开了之后不再按关键词筛选，你名下所有进程都会被钉到小核，整机会明显变慢。只在实验时短时间使用。"

    @Published public var output: String = ""
    @Published public var outputcount: Int = 0
    @Published public var isRunning: Bool = false

    @Published public var enableFocusCheck: Bool = false
    @Published public var enableBalanceCheck: Bool = true
    @Published public var CPUThreshold: String = "20"
    @Published public var BalanceThreshold: String = "100"

    @Published public var enableFPSCheck: Bool = false
    @Published public var fpsVarianceThreshold: String = "2"

    @Published public var runScriptText: String = ""
    @Published public var enablePerformanceCore: Bool = false

    @AppStorage("enableDefaultRules") public var enableDefaultRules: Bool = true
    @Published public var defaultAtternsString: String = "Renderer|bilibili|wine"
    @Published public var regex: String = ""
    @Published public var isDetectingPower: Bool = true

    // Live process table data – updated by parsing script stdout
    @Published public var assignedProcesses: [TrackedProcess] = []

    // Phase tracking – drives spinner and countdown in the UI
    @Published public var scriptPhase: ScriptPhase = .idle
    @Published public var sleepCountdown: Int = 0
    private var countdownTimer: Timer?

    private init() {}

    // MARK: - Phase: countdown

    func startCountdown(from seconds: Int) {
        countdownTimer?.invalidate()
        sleepCountdown = seconds
        scriptPhase = .sleeping(seconds)
        guard seconds > 0 else { return }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.sleepCountdown > 1 {
                self.sleepCountdown -= 1
                self.scriptPhase = .sleeping(self.sleepCountdown)
            } else {
                self.sleepCountdown = 0
                timer.invalidate()
                self.countdownTimer = nil
            }
        }
    }

    func clearProcesses() {
        assignedProcesses = []
        scriptPhase = .idle
        sleepCountdown = 0
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - Output parsing
    //
    // Called on the main thread from every readabilityHandler chunk.
    // Matches five line shapes:
    //   [HH:MM]                                              → .scanning
    //   Assigned 'NAME' (PID N) to efficiency|performance   → upsert row
    //   [REASSIGN] PID N ... sending to performance cores   → update row
    //   [REASSIGN] PID N ... sending back to efficiency     → update row
    //   Current sleep time: N seconds                       → .sleeping(N) + countdown

    private static let timestampRE = try! NSRegularExpression(pattern: #"^\[\d{2}:\d{2}\]$"#)
    private static let assignedRE  = try! NSRegularExpression(
        pattern: #"Assigned '(.*)' \(PID (\d+)\) to (efficiency|performance) cores"#
    )
    private static let toPerfRE   = try! NSRegularExpression(
        pattern: #"\[REASSIGN\] PID (\d+).+sending to performance cores"#
    )
    private static let toEffRE    = try! NSRegularExpression(
        pattern: #"\[REASSIGN\] PID (\d+).+sending back to efficiency cores"#
    )
    private static let sleepRE    = try! NSRegularExpression(
        pattern: #"Current sleep time: (\d+) seconds"#
    )

    func parseAndUpdateProcesses(from text: String) {
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            let nsRange = NSRange(t.startIndex..., in: t)

            if Self.timestampRE.firstMatch(in: t, range: nsRange) != nil {
                // New loop cycle – show spinner
                scriptPhase = .scanning

            } else if let m = Self.assignedRE.firstMatch(in: t, range: nsRange), m.numberOfRanges == 4,
                      let nr = Range(m.range(at: 1), in: t),
                      let pr = Range(m.range(at: 2), in: t),
                      let cr = Range(m.range(at: 3), in: t),
                      let pid = Int(t[pr]) {
                let name = String(t[nr])
                let core: CoreAssignment = t[cr] == "efficiency" ? .efficiency : .performance
                upsert(TrackedProcess(id: pid, name: name.isEmpty ? "PID \(pid)" : name, coreAssignment: core))

            } else if let m = Self.toPerfRE.firstMatch(in: t, range: nsRange), m.numberOfRanges == 2,
                      let pr = Range(m.range(at: 1), in: t), let pid = Int(t[pr]) {
                scriptPhase = .scanning
                updateCore(pid: pid, to: .performance)

            } else if let m = Self.toEffRE.firstMatch(in: t, range: nsRange), m.numberOfRanges == 2,
                      let pr = Range(m.range(at: 1), in: t), let pid = Int(t[pr]) {
                scriptPhase = .scanning
                updateCore(pid: pid, to: .efficiency)

            } else if let m = Self.sleepRE.firstMatch(in: t, range: nsRange), m.numberOfRanges == 2,
                      let pr = Range(m.range(at: 1), in: t), let secs = Int(t[pr]) {
                // Scan complete – start the visible countdown
                startCountdown(from: secs)
            }
        }
    }

    // MARK: - Private helpers

    private func upsert(_ process: TrackedProcess) {
        withAnimation(.easeOut(duration: 0.22)) {
            if let idx = assignedProcesses.firstIndex(where: { $0.id == process.id }) {
                assignedProcesses[idx] = process
            } else {
                assignedProcesses.append(process)
            }
        }
    }

    private func updateCore(pid: Int, to core: CoreAssignment) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let idx = assignedProcesses.firstIndex(where: { $0.id == pid }) {
                assignedProcesses[idx].coreAssignment = core
            }
        }
    }
}
