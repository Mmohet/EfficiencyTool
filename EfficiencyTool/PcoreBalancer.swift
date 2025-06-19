// PcoreBalancer.swift
import Foundation
import Combine
import SwiftUI

public class PcoreBalancer: ObservableObject {
    public static let shared = PcoreBalancer()
    @ObservedObject var config = AppStorageConfig.config
    @State public var output = ""

    public func start() {
        config.output = ""

        let patterns = config.getCustomPatterns()
        let psCommand: String
        if config.useAltPSCommand {
            psCommand = """
ps aux | grep -v grep | grep -v GPU | awk '$1!="root" && $1!="Apple" && $1 !~ /^_/{ print $2 }'
"""
        } else {
            // let regex = patterns.joined(separator: "|")
            psCommand = "ps aux | grep -E '\(config.regex)' | grep -v grep | grep -v GPU | grep -v server | awk '{print $2}'"
        }

        var script = """
        #!/bin/bash
        
        assigned_pids=()
        taskpolicy -b -p $$
        echo "sent $$ bash"

        while true; do
            CPU_USAGE=$(ps -A -o %cpu | awk 'NR>1 {s+=$1} END {printf "%.0f\\n", s/NR*100}')
            if [[ $CPU_USAGE -gt 20 ]]; then
                for pid in $(\(psCommand)); do
                    cpu_usage=$(ps -p $pid -o %cpu= | awk '{print $1}')
                    cpu_int=${cpu_usage%.*}
                    if [[ $cpu_int -gt 70 ]]; then
                        echo "[REASSIGN] PID $pid using ${cpu_usage}% CPU — sending to performance cores"
                        taskpolicy -B -p $pid
                       assigned_pids+=($pid)
                    fi

                    if [[ $cpu_int -lt 70 ]]; then
                        if [[ " ${assigned_pids[@]} " =~ " ${pid} " ]]; then
                        echo "[REASSIGN] PID $pid using ${cpu_usage}% CPU — sending back to efficiency cores"
                            taskpolicy -b -p $pid
                            assigned_pids=("${assigned_pids[@]/$pid}")
                        fi
                    fi
                    
                done
            fi
            sleep 1
        done
        """

        let newPipe = Pipe()
        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        newProcess.arguments = ["-c", script]
        newProcess.standardOutput = newPipe
        newProcess.standardError = newPipe

        config.pipe = newPipe
        config.process = newProcess

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
    }

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
    }
}
