# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Build and run via Xcode — open `EfficiencyTool.xcodeproj`. No package manager (no SPM, no CocoaPods). macOS 14+ required, Apple Silicon recommended.

```bash
# CLI build (from repo root)
xcodebuild -project EfficiencyTool.xcodeproj -scheme EfficiencyTool -configuration Debug build

# Run tests
xcodebuild test -project EfficiencyTool.xcodeproj -scheme EfficiencyTool
```

## Architecture

macOS menu bar app. No SwiftUI `WindowGroup` — the app entry point uses `Settings { EmptyView() }` to suppress the default window, and `AppDelegate` manages everything via `NSStatusItem`.

**Singletons (all `ObservableObject`):**
- `AppStorageConfig.config` — all user settings and state. Persists via `@AppStorage`. Central store shared across all classes.
- `ScriptRunner.shared` — builds and runs the main bash script as a child `Process`. Reads stdout/stderr via `Pipe` and appends to `config.output`.
- `PcoreBalancer.shared` — runs a second concurrent bash script when balance mode is on. Monitors CPU usage and dynamically moves PIDs between efficiency/performance cores.
- `StopScript.shared` — runs once on script stop to send all PIDs back to performance cores (restoring default policy).
- `Language.config` — holds all UI strings. Populated at launch by `EfficiencyToolApp.init()` based on `Locale.preferredLanguages[0]`.

**Flow:**
1. `EfficiencyToolApp` → sets language, wires `AppDelegate` via `@NSApplicationDelegateAdaptor`.
2. `AppDelegate.applicationDidFinishLaunching` → creates the status bar item and menu, calls `showWindow()`.
3. `showWindow()` → lazily creates `NSWindow` hosting `ContentView` (SwiftUI), shows it. Closing the window hides the Dock icon (`.accessory` policy); reopening restores it.
4. Start/Stop in UI or menu → `ScriptRunner.start()` / `.stop()`. Start also calls `PcoreBalancer.start()` if balance mode enabled. Stop calls `StopScript.start()` to reverse assignments.

**Bash scripts** are constructed as inline Swift strings inside `ScriptRunner.start()` and `PcoreBalancer.start()`, interpolating Swift config values directly into the script text. The main loop uses `taskpolicy -b -p <pid>` (efficiency) or `-B` (performance). `assigned_pids` array prevents re-assigning already-handled PIDs. Sleep time is dynamically adjusted based on how many new PIDs were found.

## Localization

`Language.swift` is the single source of truth for UI strings — not `.strings` files (those exist but the app uses the `Language` class). Add new strings by: (1) adding a `@Published var` to `Language`, (2) setting values in both `setEnglish()` and `setChinese()`, (3) referencing `language.<prop>` in views.

The `.lproj` string files in `zh-Hans.lproj/` and `en.lproj/` appear to be legacy/unused.

## Key Behaviors

- **Default rules**: `"Renderer|bilibili|wine"` regex (`config.defaultAtternsString`). Always enabled when no custom patterns exist.
- **Balance mode** (`enableBalanceCheck`): disabled automatically when performance core mode is on.
- **Power adapter detection** (`isDetectingPower`): script skips the assignment loop when on AC power (battery-only by default).
- **Output buffer**: cleared at 100 lines to prevent unbounded memory growth.
- **`taskpolicy`**: macOS system binary — not available in the iOS simulator or on non-Apple-Silicon hardware.
