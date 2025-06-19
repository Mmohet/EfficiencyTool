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

public class ScriptRunner: ObservableObject {
    public static let shared = ScriptRunner()
    @ObservedObject var config = AppStorageConfig.config
    @ObservedObject private var pcorerunner = PcoreBalancer.shared
    @State public var output = ""

    /// 启动并传入当前配置
    public func start() {
        print (config.useAltPSCommand)
        config.output = ""

        let patterns = config.getCustomPatterns()
        let psCommand: String
        if config.useAltPSCommand {
            psCommand = """
ps aux | grep -v grep | grep -v GPU | awk '$1!="root" && $1!="Apple" && $1 !~ /^_/{ print $2 }'
"""
        } else {
            var regex = ""
            if (patterns == []) {
                config.enableDefaultRules = true
            }
            if (config.enableDefaultRules) {
                regex = config.defaultAtternsString
                if (patterns != []) {
                    regex += "|"
                    regex +=  patterns
                        .joined(separator: "|")
                }
                print (regex)
            } else {
                regex = patterns
                    .joined(separator: "|")
            }

            psCommand = "ps aux | grep -E '\(regex)' | grep -v grep | grep -v GPU | grep -v server | awk '{print $2}'"
        }
        
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
               taskpolicy -b -p $pid
               full_path=$(ps -p $pid -o comm=)
               process_name=$(echo "$full_path" | sed -E 's#.*/([^/]*\\.app)/.*MacOS/##')
               echo "Assigned '$process_name' (PID $pid) to efficiency cores"
               assigned_pids+=($pid)
             fi
           done

        """


        // 如果启用了 Minecraft 检测，追加相关逻辑
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

        config.pipe = newPipe
        config.process = newProcess

        // 实时读取输出
        newPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                [weak self] in
                guard let self = self else { return }
                self.config.output += str
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
        config.process?.terminate()
        config.process = nil
        config.pipe?.fileHandleForReading.readabilityHandler = nil
        config.pipe = nil
        config.isRunning = false
        DispatchQueue.main.async {
            self.config.output += "\n[脚本已停止]\n"
        }
        NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
        pcorerunner.stop()
    }
}
extension Notification.Name {
    static let scriptStateChanged = Notification.Name("scriptStateChanged")
}
