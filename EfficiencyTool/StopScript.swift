// StopScript.swift
import Foundation
import Combine
import SwiftUI

public class StopScript: ObservableObject {
    public static let shared = StopScript()
    @ObservedObject var config = AppStorageConfig.config
    @State public var output = ""
    public var process: Process? = nil
    public var pipe: Pipe? = nil
    public func start() {
        config.output = ""

        
        
        let script = """
        #!/bin/bash
        assigned_pids=()

            timestamp=$(date "+%H:%M")
            echo "[$timestamp]"

            for pid in $(ps aux | grep -v grep | grep -v GPU | awk '$1!="root" && $1!="Apple" && $1 !~ /^_/{ print $2 }'); do
                if [[ ! " ${assigned_pids[@]} " =~ " ${pid} " ]]; then
                    taskpolicy -B -p $pid
                    assigned_pids+=($pid)
                    full_path=$(ps -p $pid -o comm=)
                    process_name=$(echo "$full_path" | sed -E 's#.*/([^/]*\\.app)/.*MacOS/##')
                    echo "Assigned '$process_name' (PID $pid) to efficiency cores"
                fi
            done
        """





        let newPipe = Pipe()
        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        newProcess.arguments = ["-c", script]
        newProcess.standardOutput = newPipe
        newProcess.standardError = newPipe

        pipe = newPipe
        process = newProcess

        // Read output asynchronously
        newPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.config.output += output
                }
            }
        }

        // Handle process termination (auto-stop)
        newProcess.terminationHandler = { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.pipe?.fileHandleForReading.readabilityHandler = nil
                self.pipe = nil
                self.process = nil
                self.config.output += "\n[pid已送回原进程]\n"
            }
        }

        do {
            try newProcess.run()
        } catch {
            DispatchQueue.main.async {
                self.config.output = "送回pid失败：\(error)"
            }
        }
    }
}
