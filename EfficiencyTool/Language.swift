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

    }
    
    
    
    
    
    
}
