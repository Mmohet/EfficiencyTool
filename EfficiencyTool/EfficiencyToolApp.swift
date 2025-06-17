import SwiftUI
import AppKit

@main
struct EfficiencyToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // @StateObject private var manager = ScriptManager()

    var body: some Scene {
        // 隐藏默认窗口
        Settings { EmptyView() }
    }
}
