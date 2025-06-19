// AppStorage Variables.swift
// 用于持久化用户配置的示例

import SwiftUI

/// 配置存储与管理
class AppStorageConfig: ObservableObject {
    public static var config = AppStorageConfig()
    @AppStorage("customPatterns") public var customPatternsString: String = ""
    @Published var customPatterns: [String] = []

    func getCustomPatterns() -> [String] {
        customPatternsString.isEmpty ? [] : customPatternsString.components(separatedBy: ",")
    }

    func setCustomPatterns(_ patterns: [String]) {
        customPatternsString = patterns.joined(separator: ",")
    }

    @Published public var newCustomPattern: String = ""
    
    @Published public var useAltPSCommand: Bool = false
    public let altPSWarning = "⚠️ 启用此选项将完全替代默认的进程筛选命令，会将整个系统进程都放入小核, 建议仅在必要时使用。"
    
    @Published public var output: String = ""
    @Published public var isRunning: Bool = false
    @Published public var process: Process? = nil
    @Published public var pipe: Pipe? = nil
    
    // 前台 检测开关
    @Published public var enableFocusCheck: Bool = false
    @Published public var enableBalanceCheck: Bool = true

    @Published public var runScriptText: String = ""
    
    @Published public var isLowPowerModeEnabled: Bool = false
    
    @Published public var enableDefaultRules: Bool = true
    @Published public var defaultAtternsString: String = "Renderer|bilibili|wine"

    
    private init() {}
}


