import SwiftUI
import AppKit
import Cocoa

extension Notification.Name {
    static let startScript = Notification.Name("StartScriptNotification")
    static let pauseScript = Notification.Name("PauseScriptNotification")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    
    var window: NSWindow?
    
    @objc func updateMenuToggleText() {
        toggleItem.title = config.isRunning ? language.stop_script : language.run_script
    }
    
    @ObservedObject public var runner = ScriptRunner.shared
    let config = AppStorageConfig.config
    @ObservedObject private var language = Language.config

    
    var statusItem: NSStatusItem!
    var toggleItem: NSMenuItem!
    func applicationSupportsSecureRestorableState() -> Bool {
        return true
    }

    func application(_ application: NSApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        return false
    }

    
    func applicationDidFinishLaunching(_ notification: Notification) {

        // Setup status bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "speedometer", accessibilityDescription: nil)

        let menu = NSMenu()
        toggleItem = NSMenuItem(title: language.run_script, action: #selector(toggleScript), keyEquivalent: "S")
        toggleItem.target = self
        menu.addItem(toggleItem)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuToggleText),
            name: .scriptStateChanged,
            object: nil
        )
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: language.show_window, action: #selector(showWindow), keyEquivalent: "W"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: language.quit, action: #selector(quitApp), keyEquivalent: "Q"))

        statusItem.menu = menu
        showWindow()
    }

    @objc private func toggleScript() {
        if !config.isRunning {
            print("Starting script... useAltPS: \(config.useAltPSCommand)")
            ScriptRunner.shared.start()
            config.isRunning = true
            updateMenuToggleText()
            NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
            // toggleItem.title = config.runScriptText
        } else {
            print("Stopping script... useAltPS: \(config.useAltPSCommand)")
            ScriptRunner.shared.stop()
            config.isRunning = false
            updateMenuToggleText()
            NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
            // toggleItem.title = config.runScriptText
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
            window?.identifier = nil
            window?.isRestorable = false
            window?.isReleasedWhenClosed = false
            window?.center()
            window?.contentView = NSHostingView(rootView: contentView)
            window?.delegate = self // 💡 Very important
        }
        NSApp.setActivationPolicy(.regular)    // shows Dock icon
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        ScriptRunner.shared.stop()
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // This ensures window gets recreated properly next time
        self.window = nil
        NSApp.setActivationPolicy(.accessory) // 👉 hide dock icon
    }
}
