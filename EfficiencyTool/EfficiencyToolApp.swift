import SwiftUI
import AppKit

@main
struct EfficiencyToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var language = Language.config
    
    // Setting up languages
    init() {
        let pre = Locale.preferredLanguages[0]

        if pre.hasPrefix("en") {
            language.setEnglish()
        } else if pre.hasPrefix("yue") {
            language.setChinese()
        } else if pre.hasPrefix("zh") {
            language.setChinese()
        }
    }
    var body: some Scene {
        // 隐藏默认窗口
        Settings { EmptyView() }
    }
}
