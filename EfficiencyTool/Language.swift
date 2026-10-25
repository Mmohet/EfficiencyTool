import Foundation


// language storage
// each function setup in EfficiencyTOolApp
// 所有界面文案的唯一来源。新增文案时：
// 1) 在这里加 @Published var；2) 在易用/专业两套赋值函数里各赋值；3) 视图里用 language.<key>。
//
// 文案分两层：
//   标签层（customize_rules 等）→ 易用模式用"人话"，专业模式保持上游原文案
//   共享层（悬浮提示 help_*、应用选择器 picker_*）→ 两种模式共用，纯增量不影响原界面
public class Language: ObservableObject {


    public static var config = Language()

    private var isChinese = false
    private var isPro = false

    /// 启动时按系统语言 + 已保存的模式一次性应用
    public func apply(chinese: Bool, pro: Bool) {
        isChinese = chinese
        isPro = pro
        chinese ? setChinese() : setEnglish()
    }

    /// 界面开关切换模式时重新应用文案
    public func setProMode(_ on: Bool) {
        guard on != isPro else { return }
        isPro = on
        isChinese ? setChinese() : setEnglish()
    }

    //     @Published public var newCustomPattern: String = ""
    @Published public var customize_rules: String = ""
    @Published public var new_rule: String = ""
    @Published public var add: String = ""
    @Published public var advanced_setting: String = ""
    @Published public var global_search: String = ""
    @Published public var use_focus_check: String = ""
    @Published public var use_balance_mode: String = ""
    @Published public var use_default_rules: String = ""
    @Published public var reverse_performance_core: String = ""
    @Published public var balance_settings: String = ""
    @Published public var check_threshold: String = ""
    @Published public var send_threshold: String = ""
    @Published public var stop_script: String = ""
    @Published public var run_script: String = ""
    @Published public var console_output: String = ""
    @Published public var end_script_help: String = ""
    @Published public var show_window: String = ""
    @Published public var quit: String = ""
    @Published public var fps_check_label: String = ""
    @Published public var fps_threshold_label: String = ""
    @Published public var active_processes: String = ""
    @Published public var idle: String = ""
    @Published public var running: String = ""
    @Published public var monitoring: String = ""
    @Published public var efficiency: String = ""
    @Published public var performance: String = ""
    @Published public var mixed: String = ""
    @Published public var no_custom_keywords: String = ""
    @Published public var waiting_for_processes: String = ""
    @Published public var start_tracking_processes: String = ""
    @Published public var power_adapter_mode: String = ""
    @Published public var starting: String = ""
    @Published public var scanning: String = ""
    @Published public var next_in: String = ""
    @Published public var process: String = ""
    @Published public var pid: String = ""
    @Published public var core: String = ""
    @Published public var seconds_suffix: String = ""
    @Published public var remove_keyword: String = ""

    // ---- 模式开关 ----
    @Published public var mode_easy: String = ""
    @Published public var mode_pro: String = ""
    @Published public var help_mode: String = ""

    // ---- 每个选项的悬浮提示（鼠标悬停显示的"人话"解释，两种模式共用，纯增量） ----
    @Published public var help_custom_keywords: String = ""
    @Published public var help_global_search: String = ""
    @Published public var help_focus_check: String = ""
    @Published public var help_balance_mode: String = ""
    @Published public var help_default_rules: String = ""
    @Published public var help_performance_core: String = ""
    @Published public var help_power_adapter: String = ""
    @Published public var help_check_threshold: String = ""
    @Published public var help_send_threshold: String = ""
    @Published public var help_fps_check: String = ""
    @Published public var help_fps_threshold: String = ""
    @Published public var default_rules_caption: String = ""

    // ---- 「正在运行的应用」选择卡片 ----
    @Published public var picker_title: String = ""
    @Published public var picker_search: String = ""
    @Published public var picker_empty: String = ""
    @Published public var picker_procs: String = ""
    @Published public var picker_limit_now: String = ""
    @Published public var picker_restore_now: String = ""
    @Published public var picker_add_rule: String = ""
    @Published public var picker_added: String = ""
    @Published public var picker_policy_e: String = ""
    @Published public var picker_policy_p: String = ""
    @Published public var picker_help: String = ""
    @Published public var picker_log_limit: String = ""
    @Published public var picker_log_restore: String = ""
    @Published public var picker_log_none: String = ""
    @Published public var picker_log_rule: String = ""
    @Published public var picker_refreshed_at: String = ""


    public func setEnglish() {
        if isPro {
            customize_rules = "Monitor process mode (custom)"
            new_rule = "Customized keyword"
            add = "Add"
            advanced_setting = "Advanced options"
            global_search = "Use global search instead of process grabbing command"
            use_focus_check = "Enable foreground(focus) detection"
            use_balance_mode = "Enable balanced mode"
            use_default_rules = "Enable default rules"
            reverse_performance_core = "Enable custom performance core mode"
            balance_settings = "Balance options"
            check_threshold = "Check threshold"
            send_threshold = "Send threshold"
            stop_script = "Stop script"
            run_script = "Run script"
            console_output = "Terminal output:"
            end_script_help = "If you want to close the script, stop the script, exit the application and re-launch it. For global search, just restart"
            active_processes = "Active Processes"
            no_custom_keywords = "No custom keywords — using defaults"
            waiting_for_processes = "Waiting for processes to be assigned…"
            start_tracking_processes = "Start the script to begin tracking processes"
            power_adapter_mode = "Detect Power Adapter Mode"
            next_in = "Next in"
            core = "Core"
        } else {
            customize_rules = "Auto-manage keywords (long-term saving)"
            new_rule = "Type a keyword, e.g. Chrome"
            add = "Add"
            advanced_setting = "Advanced (usually leave as is)"
            global_search = "Take over ALL my processes (risky)"
            use_focus_check = "Also limit the app I'm using (will lag)"
            use_balance_mode = "Auto-unthrottle when busy (recommended)"
            use_default_rules = "Use built-in recommended rules (browsers etc.)"
            reverse_performance_core = "Reverse mode: pin to fast cores instead"
            balance_settings = "Auto-unthrottle settings"
            check_threshold = "Whole-system CPU check level (%)"
            send_threshold = "Per-process release level (%)"
            stop_script = "Stop monitoring"
            run_script = "Start monitoring"
            console_output = "Log"
            end_script_help = "Tip: press “Stop monitoring” to automatically restore every limited process; or simply quit and reopen the affected app. Global-search effects wear off after an app restart."
            active_processes = "Managed processes"
            no_custom_keywords = "No custom keywords yet"
            waiting_for_processes = "Waiting for matching processes…"
            start_tracking_processes = "Press “Start monitoring” to track managed processes here"
            power_adapter_mode = "Only when on battery (skip on charger)"
            next_in = "Next scan"
            core = "Core"
        }
        // 以下两组文案两模式原本就相同
        show_window = "Show window"
        quit = "Quit Efficiency Tool"
        fps_check_label = "Enable animation hitch detection (xctrace)"
        fps_threshold_label = "Hitch threshold (per 2s)"
        idle = "Idle"
        running = "Running"
        monitoring = "Monitoring"
        efficiency = "Efficiency"
        performance = "Performance"
        mixed = "Mixed"
        starting = "Starting…"
        scanning = "Scanning…"
        process = "Process"
        pid = "PID"
        seconds_suffix = "s"
        remove_keyword = "Remove %@"

        mode_easy = "Easy"
        mode_pro = "Pro"
        help_mode = "Easy mode: plain-language labels, advanced options hidden, safe defaults — for everyday use. Pro mode: the full original UI with every option and threshold. Switch takes effect immediately and is remembered."

        help_custom_keywords = "Keywords match the full command line of processes. For example “Chrome” matches the browser and every tab/helper process."
        help_global_search = "Ignores keywords and pins EVERY process under your account to efficiency cores. Slows the whole machine — for experiments only."
        help_focus_check = "Also pins the app you are currently using to efficiency cores. Expect visible lag — only for extreme battery saving."
        help_balance_mode = "Recommended. If a limited process gets busy (CPU above the release level below), it is temporarily moved back to fast cores, then re-limited once idle."
        help_default_rules = "Automatically limits browser renderer processes (Renderer), bilibili and wine apps. Works best with Chromium browsers (Chrome/Edge/Arc…)."
        help_performance_core = "Reversed: matching processes get pinned to PERFORMANCE cores to speed them up. Power-saving options are ignored in this mode."
        help_power_adapter = "ON: limit only while on battery, do nothing while plugged in. OFF: always limit."
        help_check_threshold = "Per-proces checks only start when total system CPU exceeds this percentage. Default 20."
        help_send_threshold = "A limited process whose CPU exceeds this percentage is released back to fast cores to avoid lag. Default 100 (effectively never)."
        help_fps_check = "Experimental: uses Xcode's xctrace to detect stutter in the frontmost app and frees the real culprit renderer. Heavy — skip if you don't notice stutter."
        help_fps_threshold = "Number of hitches per 2 seconds before it is considered stutter."
        default_rules_caption = "Built-in rules: browser renderer processes (Renderer), bilibili, wine — best for Chromium browsers."

        picker_title = "Running apps — one click to save power"
        picker_search = "Search apps…"
        picker_empty = "No matching app"
        picker_procs = "%d procs"
        picker_limit_now = "Save power"
        picker_restore_now = "Restore"
        picker_add_rule = "Watch"
        picker_added = "Watching"
        picker_policy_e = "E-core"
        picker_policy_p = "P-core"
        picker_help = "“Save power” pins all processes of the app to efficiency cores RIGHT NOW (no need to start monitoring). “Restore” releases them back. “Watch” saves the app as a keyword so the monitor manages it (and its future processes) automatically."
        picker_log_limit = "[Save] %@: %d process(es) pinned to efficiency cores ✔"
        picker_log_restore = "[Restore] %@: %d process(es) back on performance cores"
        picker_log_none = "[Info] no running process found for %@"
        picker_log_rule = "[Rule] “%@” added to auto-manage keywords"
        picker_refreshed_at = "updated %@"
    }

    public func setChinese() {
        if isPro {
            customize_rules = "监控进程模式 (自定义)";
            new_rule = "自定义关键字";
            add = "添加";
            advanced_setting = "高级选项";
            global_search = "使用全局搜索替代进程抓取命令";
            use_focus_check = "启用前台检测";
            use_balance_mode = "启用均衡模式";
            use_default_rules = "启用默认规则";
            reverse_performance_core = "启用自定义大核模式";
            balance_settings = "均衡选项";
            check_threshold = "检测阈值"
            send_threshold = "生效阈值";
            stop_script = "停止脚本";
            run_script = "运行脚本";
            console_output = "终端输出:";
            end_script_help = "如果想取消效果则关闭脚本并退出生效的应用并重进即可，对于全局搜索则重启即可";
            active_processes = "活动进程"
            no_custom_keywords = "暂无自定义关键字，当前使用默认规则"
            waiting_for_processes = "等待分配进程…"
            start_tracking_processes = "运行脚本以开始追踪进程"
            power_adapter_mode = "检测电源适配器模式"
            next_in = "将在"
            core = "核心"
        } else {
            customize_rules = "自动监控关键词（长期省电）";
            new_rule = "手动输入关键词，如 Chrome";
            add = "添加";
            advanced_setting = "高级选项（一般不用改）";
            global_search = "接管所有用户进程（危险）";
            use_focus_check = "限制当前正在用的 App（会卡）";
            use_balance_mode = "智能保速：忙时自动放回大核";
            use_default_rules = "使用内置推荐规则（浏览器等）";
            reverse_performance_core = "反向模式：改为钉到大核提速";
            balance_settings = "智能保速的参数";
            check_threshold = "整机 CPU 检查线（%）"
            send_threshold = "单进程放行线（%）";
            stop_script = "停止监控";
            run_script = "开始监控";
            console_output = "运行日志";
            end_script_help = "提示：点「停止监控」会自动把所有被限制的进程恢复默认；也可以直接退出并重开对应应用。全局接管模式在应用重启后失效。";
            active_processes = "已被接管的进程"
            no_custom_keywords = "还没有自定义关键词"
            waiting_for_processes = "正在等待目标进程出现…"
            start_tracking_processes = "点「开始监控」后，这里会实时显示被接管的进程"
            power_adapter_mode = "只在用电池时生效（插电不限制）"
            next_in = "下次扫描"
            core = "当前核心"
        }
        // 以下两组文案两模式原本就相同
        show_window = "显示窗口";
        quit = "退出";
        fps_check_label = "启用动画卡顿检测 (xctrace)"
        fps_threshold_label = "卡顿阈值 (每2秒)"
        idle = "空闲"
        running = "运行中"
        monitoring = "监控中"
        efficiency = "能效核心"
        performance = "性能核心"
        mixed = "混合"
        starting = "启动中…"
        scanning = "扫描中…"
        process = "进程"
        pid = "PID"
        seconds_suffix = "秒"
        remove_keyword = "移除 %@"

        mode_easy = "易用"
        mode_pro = "专业"
        help_mode = "易用模式：文案说人话、隐藏高级选项、使用安全默认值，适合日常省电。专业模式：显示完整的原始界面和全部参数。切换立即生效并自动记住。"

        help_custom_keywords = "关键词会匹配进程的完整命令行。比如填 Chrome，浏览器主进程和所有标签页、助手续程都会被匹配到。"
        help_global_search = "不再按关键词筛选，直接把你名下所有进程全部钉到小核。整机会明显变慢，一般别开，仅做实验时用。"
        help_focus_check = "把当前正在使用的 App 也钉到小核，正在操作的界面会明显卡顿。除非要极限省电，否则别开。"
        help_balance_mode = "建议开启。被钉到小核的进程一旦忙起来（CPU 超过下面的放行线），会自动临时放回大核防止卡顿，闲下来再收回小核。"
        help_default_rules = "自动省电：浏览器网页渲染进程（Renderer）、哔哩哔哩客户端、wine 应用。对 Chrome/Edge/Arc 等 Chromium 系浏览器效果最好。"
        help_performance_core = "反向操作：把匹配到的进程钉到性能大核，给特定 App 提速。此模式下省电相关选项会失效。"
        help_power_adapter = "开启后：插着电源时不做任何限制，只在用电池时才把进程钉到小核以延长续航。关闭则任何时候都生效。"
        help_check_threshold = "整机 CPU 总占用超过这个百分比，才开始逐个检查进程；低于就跳过，节省资源。默认 20。"
        help_send_threshold = "被限制的进程 CPU 超过这个百分比就放回大核，避免卡顿。默认 100（基本等于不放行）。"
        help_fps_check = "实验功能：用 Xcode 的 xctrace 检测前台 App 是否掉帧，并自动找出真正拖慢画面的渲染进程放回大核。开销较大，没装 Xcode 无法使用。"
        help_fps_threshold = "每 2 秒掉帧次数达到这个数，才判定为卡顿并开始处理。"
        default_rules_caption = "内置规则：浏览器网页渲染进程（Renderer）、哔哩哔哩、wine —— 对 Chromium 系浏览器最有效。"

        picker_title = "正在运行的应用（点一下立即省电）"
        picker_search = "搜索应用…"
        picker_empty = "没有找到匹配的应用"
        picker_procs = "%d 个进程"
        picker_limit_now = "省电"
        picker_restore_now = "恢复"
        picker_add_rule = "监控"
        picker_added = "已监控"
        picker_policy_e = "小核"
        picker_policy_p = "大核"
        picker_help = "「省电」立刻把该 App 的全部进程钉到小核（立即生效，无需点「开始监控」）；「恢复」解除限制放回大核；「监控」把该 App 存为关键词，之后点「开始监控」即可自动长期管理（包括它以后新开的进程）。"
        picker_log_limit = "[省电] 「%@」的 %d 个进程已钉到小核 ✔"
        picker_log_restore = "[恢复] 「%@」的 %d 个进程已放回大核"
        picker_log_none = "[提示] 没有找到「%@」仍在运行的进程"
        picker_log_rule = "[规则] 已把「%@」加入自动监控关键词"
        picker_refreshed_at = "更新于 %@"
    }
}
