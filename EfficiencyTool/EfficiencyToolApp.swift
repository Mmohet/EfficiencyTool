import SwiftUI
import AppKit

@main
struct EfficiencyToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var language = Language.config
    
    // Setting up languages
    init() {
        let pre = Locale.preferredLanguages[0]
        let chinese = pre.hasPrefix("zh") || pre.hasPrefix("yue")

        // 按系统语言 + 上次选择的易用/专业模式应用文案
        language.apply(chinese: chinese, pro: !AppStorageConfig.config.useSimpleMode)
    }
    var body: some Scene {
        // 隐藏默认窗口
        Settings { EmptyView() }
    }
}
