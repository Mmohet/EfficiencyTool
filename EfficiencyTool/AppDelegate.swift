import SwiftUI
import AppKit
import Cocoa

extension Notification.Name {
  static let startScript = Notification.Name("StartScriptNotification")
  static let pauseScript = Notification.Name("PauseScriptNotification")
}
class AppDelegate: NSObject, NSApplicationDelegate {
        var window: NSWindow?
    @ObservedObject public var runner = ScriptRunner.shared
    // @ObservedObject public var config = AppStorageConfig.config
    let config = AppStorageConfig.config

    var statusItem: NSStatusItem!
       var toggleItem: NSMenuItem!

       func applicationDidFinishLaunching(_ notification: Notification) {
           statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
           statusItem.button?.image = NSImage(systemSymbolName: "speedometer", accessibilityDescription: nil)

           let menu = NSMenu()

           // 单一切换项
           toggleItem = NSMenuItem(title: "运行脚本", action: #selector(toggleScript), keyEquivalent: "S")
           toggleItem.target = self
           menu.addItem(toggleItem)

           menu.addItem(.separator())
           menu.addItem(.init(title: "显示窗口", action: #selector(showWindow), keyEquivalent: "W"))
           menu.addItem(.separator())
           menu.addItem(.init(title: "退出",    action: #selector(quitApp),     keyEquivalent: "Q"))

           statusItem.menu = menu
       }

       @objc private func toggleScript() {

//           // 1. 从 UserDefaults 或 AppStorageConfig 里读出所有设置
//           let defaults = UserDefaults.standard
//
//           // 自定义模式列表
//           let custom = defaults.string(forKey: "customPatterns")?
//                            .components(separatedBy: ",") ?? []
//
//           // 默认模式开关字典 （需你在界面保存到 UserDefaults）
//           let defaultPrefs = defaults.dictionary(forKey: "selectedPatterns") as? [String: Bool] ?? [:]
//           let defaultList = defaultPrefs.filter { $0.value }.map { $0.key }
//
//           // 两个布尔开关
//           let useAlt = defaults.bool(forKey: "useAltPSCommand")
//           let focus  = defaults.bool(forKey: "enableFocusCheck")

           // 2. 构建快照配置
//           let selfConfig = ScriptConfig(
//               defaultPatterns:      defaultList,
//               customPatterns:       custom,
//               useAltPS:             useAlt,
//               enableFocusCheck:     focus
//           )

           // 3. 调用 Runner 启动或停止
           if !config.isRunning {
               print (config.useAltPSCommand)
               ScriptRunner.shared.start()
               config.isRunning = true
               toggleItem.title = "停止脚本"

           } else {
               print (config.useAltPSCommand)
               ScriptRunner.shared.stop()
               config.isRunning = false
               toggleItem.title = "运行脚本"
           }
       }

    @objc func showWindow() {
        if window == nil {
            let contentView = ContentView()
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false)
            window?.center()
            window?.contentView = NSHostingView(rootView: contentView)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        ScriptRunner.shared.stop()
        NSApplication.shared.terminate(nil)
    }
}
