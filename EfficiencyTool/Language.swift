import Foundation


// language storage
// each function setup in EfficiencyTOolApp
public class Language: ObservableObject {
    
    
    public static var config = Language()
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
    
    
    public func setEnglish() {
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
        show_window = "Show window"
        quit = "Quit Efficiency Tool"
        fps_check_label = "Enable animation hitch detection (xctrace)"
        fps_threshold_label = "Hitch threshold (per 2s)"
        active_processes = "Active Processes"
        idle = "Idle"
        running = "Running"
        monitoring = "Monitoring"
        efficiency = "Efficiency"
        performance = "Performance"
        mixed = "Mixed"
        no_custom_keywords = "No custom keywords — using defaults"
        waiting_for_processes = "Waiting for processes to be assigned…"
        start_tracking_processes = "Start the script to begin tracking processes"
        power_adapter_mode = "Detect Power Adapter Mode"
        starting = "Starting…"
        scanning = "Scanning…"
        next_in = "Next in"
        process = "Process"
        pid = "PID"
        core = "Core"
        seconds_suffix = "s"
        remove_keyword = "Remove %@"
    }

    public func setChinese() {
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
        show_window = "显示窗口";
        quit = "退出";
        fps_check_label = "启用动画卡顿检测 (xctrace)"
        fps_threshold_label = "卡顿阈值 (每2秒)"
        active_processes = "活动进程"
        idle = "空闲"
        running = "运行中"
        monitoring = "监控中"
        efficiency = "能效核心"
        performance = "性能核心"
        mixed = "混合"
        no_custom_keywords = "暂无自定义关键字，当前使用默认规则"
        waiting_for_processes = "等待分配进程…"
        start_tracking_processes = "运行脚本以开始追踪进程"
        power_adapter_mode = "检测电源适配器模式"
        starting = "启动中…"
        scanning = "扫描中…"
        next_in = "将在"
        process = "进程"
        pid = "PID"
        core = "核心"
        seconds_suffix = "秒"
        remove_keyword = "移除 %@"
    }
    
    
    
    
    
    
}
