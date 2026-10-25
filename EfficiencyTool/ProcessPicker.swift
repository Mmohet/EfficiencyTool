import SwiftUI
import AppKit
import Combine

// MARK: - Models

/// 用户选择的"核心策略"。
/// efficiency  → taskpolicy -b（钉到小核省电）
/// performance → taskpolicy -B（解除限制，放回大核）
enum CorePolicy: String {
    case efficiency
    case performance
}

/// 一条正在运行的应用（GUI App），附带实时 CPU 汇总。
struct RunningApp: Identifiable {
    let id: String            // bundleIdentifier（兜底用名字）
    let name: String
    let pid: pid_t
    let icon: NSImage
    let bundlePath: String?   // 例如 "/Applications/Google Chrome.app"，用它匹配该 App 名下全部进程（含 Helper）
    var cpu: Double = 0
    var procCount: Int = 0
}

// MARK: - One-shot policy executor

/// 立即对某个应用执行 taskpolicy，不经过主监控脚本。
/// 两步执行：先 pgrep -f 找 PID（pgrep 会排除自身），再对显式 PID 列表跑 taskpolicy。
enum CorePolicyExecutor {

    /// 转义 ERE 特殊字符，避免应用名里的 . ( ) 等被当成正则。
    static func ereEscape(_ s: String) -> String {
        let meta = Set(#"\.[](){}*+?|^$"#)
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            if meta.contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    /// 同步跑一条命令拿 stdout（只在后台队列调用）。
    static func runCommand(_ launchPath: String, _ arguments: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    /// 对 app 名下所有进程（主进程 + 同 bundle 内的 Helper/渲染进程）执行策略，回调返回处理成功的进程数。
    static func apply(policy: CorePolicy, to app: RunningApp, completion: @escaping (Int) -> Void) {
        let pattern = ereEscape(app.bundlePath ?? app.name)
        DispatchQueue.global(qos: .userInitiated).async {
            let out = runCommand("/usr/bin/pgrep", ["-f", pattern])
            let pids = out.split(separator: "\n").compactMap { Int($0) }
                .filter { $0 != Int(getpid()) && $0 != Int(getppid()) }
            guard !pids.isEmpty else {
                DispatchQueue.main.async { completion(0) }
                return
            }
            let flag = policy == .efficiency ? "-b" : "-B"
            let script = """
            ok=0
            for pid in \(pids.map(String.init).joined(separator: " ")); do
              taskpolicy \(flag) -p "$pid" 2>/dev/null && ok=$((ok+1))
            done
            echo $ok
            """
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = ["-c", script]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            do {
                try p.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let n = Int(String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
                DispatchQueue.main.async { completion(n) }
            } catch {
                DispatchQueue.main.async { completion(0) }
            }
        }
    }
}

// MARK: - Live process list store

/// 定时刷新正在运行的 GUI 应用列表（图标 + 名称 + CPU 汇总 + 进程数）。
final class ProcessListStore: ObservableObject {
    static let shared = ProcessListStore()

    @Published private(set) var apps: [RunningApp] = []
    /// 本次会话内我们对哪些 App 执行过什么策略（key = RunningApp.id）
    @Published var policyState: [String: CorePolicy] = [:]

    private var timer: Timer?
    private let config = AppStorageConfig.config

    func startAutoRefresh(every interval: TimeInterval = 4) {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        // AppKit 调用留主线程
        let wsApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
            && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        guard !wsApps.isEmpty else {
            apps = []
            return
        }
        var entries: [RunningApp] = wsApps.map { ra in
            RunningApp(
                id: ra.bundleIdentifier ?? (ra.localizedName ?? String(ra.processIdentifier)),
                name: ra.localizedName ?? "PID \(ra.processIdentifier)",
                pid: ra.processIdentifier,
                icon: ra.icon ?? NSImage(),
                bundlePath: ra.bundleURL?.path
            )
        }
        let ownBundlePath = Bundle.main.bundleURL.path

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let out = CorePolicyExecutor.runCommand("/bin/ps", ["-Ao", "%cpu=,comm="])
            // 逐行解析 "  12.3 /Applications/X.app/Contents/MacOS/X"
            for line in out.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let sp = trimmed.firstIndex(of: " ") else { continue }
                let cpu = Double(trimmed[..<sp]) ?? 0
                let path = String(trimmed[trimmed.index(after: sp)...])
                    .trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty else { continue }
                guard !path.hasPrefix(ownBundlePath) else { continue }
                // 主进程和 Helper 都位于同一个 .app bundle 内，用路径前缀即可归并到同一应用
                for i in entries.indices {
                    if let bp = entries[i].bundlePath, path.hasPrefix(bp + "/") {
                        entries[i].cpu += cpu
                        entries[i].procCount += 1
                        break
                    }
                }
            }
            entries.sort {
                if $0.cpu != $1.cpu { return $0.cpu > $1.cpu }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            DispatchQueue.main.async { self?.apps = entries }
        }
    }

    // MARK: - Actions（由界面按钮触发）

    private var language: Language { Language.config }

    func limitNow(_ app: RunningApp) {
        act(.efficiency, app)
    }

    func restoreNow(_ app: RunningApp) {
        act(.performance, app)
    }

    private func act(_ policy: CorePolicy, _ app: RunningApp) {
        CorePolicyExecutor.apply(policy: policy, to: app) { [weak self] n in
            guard let self else { return }
            if n > 0 { self.policyState[app.id] = policy }
            let msg: String
            if n > 0 {
                msg = policy == .efficiency
                    ? String(format: self.language.picker_log_limit, app.name, n)
                    : String(format: self.language.picker_log_restore, app.name, n)
            } else {
                msg = String(format: self.language.picker_log_none, app.name)
            }
            self.appendLog(msg)
        }
    }

    /// 把应用名保存为监控关键词（正则安全转义），主监控脚本启动后即自动管理。
    func addToRules(_ app: RunningApp) {
        let keyword = CorePolicyExecutor.ereEscape(app.name)
        var current = config.getCustomPatterns()
        guard !current.contains(where: { $0 == keyword || $0 == app.name }) else { return }
        current.append(keyword)
        config.setCustomPatterns(current)
        appendLog(String(format: language.picker_log_rule, app.name))
    }

    func isWatched(_ app: RunningApp) -> Bool {
        let patterns = config.getCustomPatterns()
        let plain = app.name
        let escaped = CorePolicyExecutor.ereEscape(app.name)
        return patterns.contains(where: { $0 == plain || $0 == escaped })
    }

    private func appendLog(_ line: String) {
        config.output += (config.output.isEmpty ? "" : "\n") + line
        config.outputcount += 1
        if config.outputcount > 100 {
            config.output = ""
            config.outputcount = 0
        }
    }
}

// MARK: - Picker card UI

/// 「正在运行的应用」卡片：实时列表 + 每行一键 省电 / 恢复 / 加入监控。
struct ProcessPickerCard: View {
    @ObservedObject private var store = ProcessListStore.shared
    @ObservedObject private var config = AppStorageConfig.config
    @ObservedObject private var language = Language.config
    @State private var query = ""

    private var filtered: [RunningApp] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.apps }
        return store.apps.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        CardView(icon: "square.grid.2x2", title: language.picker_title) {
            HStack(spacing: 8) {
                TextField(language.picker_search, text: $query)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 150)
                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } content: {
            VStack(spacing: 0) {
                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered) { app in
                                AppRow(app: app)
                                Divider().opacity(0.5).padding(.leading, 38)
                            }
                        }
                    }
                    .frame(maxHeight: 246)
                }
                Divider().opacity(0.65)
                Text(language.picker_help)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .onAppear { store.startAutoRefresh() }
        .onDisappear { store.stopAutoRefresh() }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Text(query.isEmpty ? language.starting : language.picker_empty)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 32)
            Spacer()
        }
    }
}

// MARK: - Row

private struct AppRow: View {
    let app: RunningApp
    @ObservedObject private var store = ProcessListStore.shared
    @ObservedObject private var language = Language.config

    private var watched: Bool { store.isWatched(app) }

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if app.procCount > 1 {
                    Text(String(format: language.picker_procs, app.procCount))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            policyBadge

            Text(String(format: "%.1f%%", app.cpu))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(cpuColor)
                .frame(width: 48, alignment: .trailing)
                .help("CPU")

            actButton(icon: "leaf.fill", title: language.picker_limit_now,
                      color: .green) { store.limitNow(app) }
            actButton(icon: "arrow.uturn.backward", title: language.picker_restore_now,
                      color: .orange) { store.restoreNow(app) }

            Button {
                store.addToRules(app)
            } label: {
                if watched {
                    Label(language.picker_added, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                } else {
                    Label(language.picker_add_rule, systemImage: "plus.circle")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(watched)
            .foregroundStyle(watched ? .secondary : Color.accentColor)
            .help(language.help_custom_keywords)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var policyBadge: some View {
        if let st = store.policyState[app.id] {
            Text(st == .efficiency ? language.picker_policy_e : language.picker_policy_p)
                .font(.caption2.weight(.medium))
                .foregroundStyle(st == .efficiency ? Color.green : Color.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    (st == .efficiency ? Color.green : Color.orange).opacity(0.12),
                    in: Capsule()
                )
        }
    }

    private func actButton(icon: String, title: String, color: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .foregroundStyle(color)
        .help(title)
    }

    private var cpuColor: Color {
        if app.cpu >= 50 { return .red }
        if app.cpu >= 10 { return .orange }
        return .secondary
    }
}
