// ScriptRunner.swift
import Foundation
import Combine
import SwiftUI

/// 快照所有用户配置
public struct ScriptConfig {
    let defaultPatterns: [String]
    let customPatterns: [String]
    let useAltPS: Bool
    let enableFocusCheck: Bool
}


// Main script part
public class ScriptRunner: ObservableObject {
    public static let shared = ScriptRunner()
    @ObservedObject var config = AppStorageConfig.config
    @ObservedObject private var pcorerunner = PcoreBalancer.shared
    @ObservedObject private var Stoper = StopScript.shared
    @State public var output = ""
    public var process: Process? = nil
    public var pipe: Pipe? = nil

    /// 启动并传入当前配置
    public func start() {
        // print (config.useAltPSCommand)
        config.output = ""
        var taskpolicy = ""
        var taskpolicyOutput = ""
        if config.enablePerformanceCore { // checking for performanceCore setting
            config.enableBalanceCheck = false // disable both balanceCheck and defaultRules (Useless in performance mode)
            config.enableDefaultRules = false
            taskpolicy = "B"
            taskpolicyOutput = "performance"
        } else {
            taskpolicy = "b"
            taskpolicyOutput = "efficiency"
        }
        
        let patterns = config.getCustomPatterns()
        let psCommand: String
        if config.useAltPSCommand { // if global search
            psCommand = """
ps aux | grep -v grep | grep -v GPU | awk '$1!="root" && $1!="Apple" && $1 !~ /^_/{ print $2 }'
"""
        } else {
            // var regex = ""
            if (patterns == []) { // enable defaultrules if no custome rules added
                config.enableDefaultRules = true
            }
            if (config.enableDefaultRules) { // if defaultrules and custom both exist
                config.regex = config.defaultAtternsString
                if (patterns != []) {
                    config.regex += "|"
                    config.regex +=  patterns
                        .joined(separator: "|")
                }
                // print (config.regex)
            } else {
                config.regex = patterns
                    .joined(separator: "|")
            }

            psCommand = "ps aux | grep -E '\(config.regex)' | grep -v grep | grep -v GPU | grep -v server | awk '{print $2}'"
        }
        
        
        // puttting script
        var script = """
        #!/bin/bash

        assigned_pids=()
        sleep_time=50
        taskpolicy -b -p $$
        echo "sent $$ bash"
        while true; do
           timestamp=$(date "+%H:%M")
           echo "[$timestamp]"

           # 主循环：根据选择的模式监控进程
           for pid in $(\(psCommand)); do
             if [[ ! " ${assigned_pids[@]} " =~ " ${pid} " ]]; then
               [[ $sleep_time -gt 200 ]] && sleep_time=$((sleep_time - 46))
               [[ $sleep_time -gt 90 ]]  && sleep_time=$((sleep_time - 19))
               [[ $sleep_time -gt 15 ]]  && sleep_time=$((sleep_time - 3))
               taskpolicy -\(taskpolicy) -p $pid
               full_path=$(ps -p $pid -o comm=)
               process_name=$(echo "$full_path" | sed -E 's#.*/([^/]*\\.app)/.*MacOS/##')
               echo "Assigned '$process_name' (PID $pid) to \(taskpolicyOutput) cores"
               assigned_pids+=($pid)
               echo assigned_pids
             fi
           done
        """


        // 如果启用了 前台 检测，追加相关逻辑
        if config.enableFocusCheck {
            script += """
           front_pid=$(osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true')

           if [[ -n "$front_pid" ]]; then
               echo "Frontmost process PID: $front_pid"
               echo "Sending PID $front_pid to efficiency cores."
               # -b 表示 background / efficiency cores
               taskpolicy -b -p "$front_pid"
           else
               echo "无法获取前台应用的 PID。"
               exit 1
           fi
        """
        }

        // 追加剩余统一逻辑
        script += """
           # --- End of Updated Block ---

                  # If PID is already in the assigned list
                  if [[ $sleep_time -gt 305 ]]; then
                    sleep_time=$((sleep_time - 17))
                  fi
                  if [[ $sleep_time -gt 10 ]]; then
                    sleep_time=$((sleep_time + 1))
                  fi
                  if [[ $sleep_time -gt 90 ]]; then
                    sleep_time=$((sleep_time + 1))
                  fi
                  if [[ $sleep_time -gt 120 ]]; then
                    sleep_time=$((sleep_time + 2))
                  fi
                  if [[ $sleep_time -gt 180 ]]; then
                    sleep_time=$((sleep_time + 3))
                  fi
                  if [[ $sleep_time -gt 200 ]]; then
                    sleep_time=$((sleep_time + 5))
                  fi
                  if [[ $sleep_time -lt 15 ]]; then
                    sleep_time=$((sleep_time + 25))
                  fi
                  if [[ $sleep_time -lt 1 ]]; then
                    sleep_time=$((10))
                  fi
           echo "Current sleep time: $sleep_time seconds"
           echo -e "\\n\\n"
           sleep $sleep_time
        done
        """


        // 启动 Process
        let newPipe = Pipe()
        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        newProcess.arguments = ["-c", script]
        newProcess.standardOutput = newPipe
        newProcess.standardError = newPipe

        pipe = newPipe
        process = newProcess

        // 实时读取输出
        newPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                [weak self] in
                guard let self = self else { return }
                self.config.output += str
                config.outputcount += 1
                if self.config.outputcount > 100 {
                    self.config.output = ""
                    self.config.outputcount = 0
                }
            }
        }

        do {
            try newProcess.run()
            config.isRunning = true
            NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
        } catch {
            DispatchQueue.main.async {
                self.config.output = "启动脚本失败：\(error)"
            }
        }
        if (config.enableBalanceCheck) {
            pcorerunner.start()
        }
     }
    /// 停止脚本
    public func stop() {
        guard config.isRunning else { return }
        process?.terminate()
        process = nil
        pipe?.fileHandleForReading.readabilityHandler = nil
        pipe = nil
        config.isRunning = false
        DispatchQueue.main.async {
            self.config.output += "\n[脚本已停止]\n"
        }
        NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
        pcorerunner.stop()
        Stoper.start()

    }

//    
//    func performDelayedAction() async {
//        print("Action started.")
//        do {
//            // Sleep for 2 seconds
//            try await Task.sleep(nanoseconds: 10_000_000_000)
//            print("Action completed after delay.")
//        } catch {
//            print("Action cancelled or an error occurred: \(error.localizedDescription)")
//        }
//    }
    

}

extension Notification.Name {
    static let scriptStateChanged = Notification.Name("scriptStateChanged")
}
