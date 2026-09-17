// PcoreBalancer.swift
import Foundation
import Combine
import SwiftUI


// Balance mode
public class PcoreBalancer: ObservableObject {
    // ----
    public static let shared = PcoreBalancer()
    @ObservedObject var config = AppStorageConfig.config
    @State public var output = ""
    public var process: Process? = nil
    public var pipe: Pipe? = nil
    // ----Set up


    // -- Starting script
    public func start() {
        config.output = ""

        let psCommand: String
        if config.useAltPSCommand {
            psCommand = """
ps aux | grep -v grep | grep -v GPU | awk '$1!="root" && $1!="Apple" && $1 !~ /^_/{ print $2 }'
"""
        } else {
            psCommand = "ps aux | grep -E '\(config.regex)' | grep -v grep | grep -v GPU | grep -v server | awk '{print $2}'"
        }

        var DPP : String
        if (config.isDetectingPower) {
            DPP = "1"
        } else {
            DPP = "0"
        }

        let fpsEnabled = config.enableFPSCheck ? "1" : "0"
        let hitchThreshold = config.fpsVarianceThreshold.isEmpty ? "2" : config.fpsVarianceThreshold

        // Script part
        let script = """
        #!/bin/bash


        D_P=\(DPP)
        assigned_pids=()
        assigned_epids=()
        renderer_pids=()
        fps_last_check=0
        renderer_last_probe=0
        FPS_CHECK_ENABLED=\(fpsEnabled)
        HITCH_THRESHOLD=\(hitchThreshold)
        taskpolicy -b -p $$
        echo "sent $$ bash"

        if [[ "$FPS_CHECK_ENABLED" == "1" ]]; then
            if command -v xctrace &>/dev/null; then
                echo "[HITCH] xctrace ready: $(xctrace version 2>/dev/null | head -1)"
            else
                echo "[HITCH] xctrace not found — install Xcode Command Line Tools to enable hitch detection"
                FPS_CHECK_ENABLED=0
            fi
        fi

        measure_hitches() {
            local target_pid=$1
            [[ -z "$target_pid" ]] && echo "0" && return
            local outfile="/tmp/et_trace_${target_pid}_$$.trace"
            rm -rf "$outfile"
            xctrace record \\
                --template "Animation Hitches" \\
                --time-limit 2s \\
                --attach "$target_pid" \\
                --output "$outfile" \\
                2>/dev/null
            local count=0
            if [[ -d "$outfile" ]]; then
                count=$(xctrace export \\
                    --input "$outfile" \\
                    --xpath '/trace-toc/run/data/table[@schema="hitch-interval"]' \\
                    2>/dev/null | python3 -c '
        import sys
        d = sys.stdin.read()
        print(d.count("<row>"))
        ' 2>/dev/null || echo "0")
                rm -rf "$outfile"
            fi
            echo "${count:-0}"
        }

        while true; do
         if [[ $(pmset -g batt | grep 'AC Power' >/dev/null && printf "Power Adapter\\n" || printf "Battery\\n") == "Battery" || $D_P == "0" ]]; then
            CPU_USAGE=$(ps -A -o %cpu | awk 'NR>1 {s+=$1} END {printf "%.0f\\n", s/NR*100}')
            if [[ $CPU_USAGE -gt \(config.CPUThreshold) ]]; then
                for pid in $(\(psCommand)); do
                  # Skip renderer PIDs — managed by hitch detection
                  if [[ " ${renderer_pids[@]} " =~ " ${pid} " ]]; then
                    continue
                  fi
                  if [[ ! " ${assigned_pids[@]} " =~ " ${pid} " ]]; then
                    cpu_usage=$(ps -p $pid -o %cpu= | awk '{print $1}')
                    cpu_int=${cpu_usage%.*}
                    if [[ $cpu_int -gt \(config.BalanceThreshold) ]]; then
                        echo "[REASSIGN] PID $pid using ${cpu_usage}% CPU — sending to performance cores"
                        taskpolicy -B -p $pid
                        assigned_pids+=($pid)
                        sleep 0.1
                    fi
                  fi
                    if [[ $cpu_int -lt \(config.BalanceThreshold) ]]; then
                        if [[ " ${assigned_pids[@]} " =~ " ${pid} " ]]; then
                            echo "[REASSIGN] PID $pid using ${cpu_usage}% CPU — sending back to efficiency cores"
                            taskpolicy -b -p $pid
                            assigned_pids=("${assigned_pids[@]/$pid}")
                        fi
                    fi

                done
            fi
          fi

          # Animation hitch-based renderer detection via xctrace
          if [[ "$FPS_CHECK_ENABLED" == "1" ]]; then
            now=$(date +%s)

            if [[ $((now - fps_last_check)) -ge 15 ]]; then
                fps_last_check=$now
                front_pid=$(osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true' 2>/dev/null)
                front_name=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)

                if [[ -n "$front_pid" && -n "$front_name" ]]; then
                    baseline=$(measure_hitches "$front_pid")
                    echo "[HITCH] $front_name (PID $front_pid): ${baseline} hitches/2s"

                    if [[ $baseline -ge $HITCH_THRESHOLD ]]; then
                        if [[ $((now - renderer_last_probe)) -ge 60 ]]; then
                            renderer_last_probe=$now
                            echo "[HITCH] Threshold exceeded (${baseline} >= ${HITCH_THRESHOLD}), probing renderers..."
                            last_count=$baseline

                            while IFS= read -r pid; do
                                [[ -z "$pid" ]] && continue
                                # Skip main app process — only test worker/renderer subprocesses
                                [[ "$pid" == "$front_pid" ]] && continue
                                # Skip PIDs already on performance (CPU-assigned or confirmed renderer)
                                [[ " ${assigned_pids[@]} " =~ " ${pid} " ]] && continue
                                [[ " ${renderer_pids[@]} " =~ " ${pid} " ]] && continue

                                echo "[HITCH-PROBE] Testing PID $pid ($(ps -p $pid -o comm= 2>/dev/null))..."
                                taskpolicy -B -p "$pid"
                                sleep 0.5
                                new_count=$(measure_hitches "$front_pid")

                                if [[ $new_count -lt $last_count ]]; then
                                    echo "[HITCH-RENDERER] PID $pid confirmed renderer (hitches: ${last_count} -> ${new_count})"
                                    renderer_pids+=("$pid")
                                    last_count=$new_count
                                else
                                    echo "[HITCH-PROBE] PID $pid not renderer, back to efficiency"
                                    taskpolicy -b -p "$pid"
                                fi
                            done < <(ps aux | grep -v grep | awk -v name="$front_name" 'tolower($0) ~ tolower(name) {print $2}')
                        fi
                    fi
                fi
            fi

            # Prune dead renderer PIDs every loop
            live_renderers=()
            for rpid in "${renderer_pids[@]}"; do
                if ps -p "$rpid" > /dev/null 2>&1; then
                    live_renderers+=("$rpid")
                else
                    echo "[HITCH-RENDERER] PID $rpid exited"
                fi
            done
            renderer_pids=("${live_renderers[@]}")
          fi

            sleep 0.5
        done
        """

        // Creating pipe line
        let newPipe = Pipe()
        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        newProcess.arguments = ["-c", script]
        newProcess.standardOutput = newPipe
        newProcess.standardError = newPipe

        pipe = newPipe
        process = newProcess

        newPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                [weak self] in
                guard let self = self else { return }
                self.config.output += str
                self.config.parseAndUpdateProcesses(from: str)
            }
        }

        do {
            try newProcess.run()
            NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
        } catch {
            DispatchQueue.main.async {
                self.config.output = "启动脚本失败：\(error)"
            }
        }
    }


    // Stop part
    public func stop() {
        process?.terminate()
        process = nil
        pipe?.fileHandleForReading.readabilityHandler = nil
        pipe = nil
        DispatchQueue.main.async {
            self.config.output += "\n[脚本已停止]\n"
        }
        NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
    }
}
