import SwiftUI

struct ContentView: View {
    @State private var output = ""
    @State private var isRunning = false
    @State private var process: Process? = nil
    @State private var pipe: Pipe? = nil

    // 可选进程匹配模式列表
    private let allPatterns = ["Renderer", "Chrome", "Edge", "Reading", "bilibili", "Terminal", "wine"]
    @State private var selectedPatterns: [String: Bool] = [
        "Renderer": true,
        "Chrome": true,
        "Edge": false,
        "Reading": false,
        "bilibili": false,
        "Terminal": true,
        "wine": false
    ]

    // Minecraft/Java 检测开关
    @State private var enableFocusCheck = false

    var body: some View {
        VStack(spacing: 12) {
            // 模式选择列表（macOS 不支持 EditButton）
            GroupBox(label: Text("选择要监控的进程模式:")) {
                VStack(alignment: .leading) {
                    ForEach(allPatterns, id: \.self) { pattern in
                        Toggle(pattern, isOn: Binding(
                            get: { selectedPatterns[pattern] ?? false },
                            set: { selectedPatterns[pattern] = $0 }
                        ))
                    }
                }
                .padding()
            }

            // Minecraft 检测开关
            Toggle("启用 Minecraft/Java 前后台检测", isOn: $enableFocusCheck)
                .padding(.bottom, 8)

            // 运行/停止 按钮
            Button(isRunning ? "停止脚本" : "运行脚本") {
                isRunning ? stopScript() : startScript()
            }
            .padding(.vertical, 8)

            // 输出区域
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output)
                        .padding()
                        .font(.system(.body, design: .monospaced))
                        .id("end")
                }
                .onChange(of: output) { _ in
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 450)
    }

    private func startScript() {
        output = ""

        // 构建 grep 模式字符串
        let patterns = allPatterns
            .filter { selectedPatterns[$0] == true }
            .joined(separator: "|")

        // 生成脚本内容
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
           for pid in $(ps aux | grep -E '\(patterns)' | grep -v grep | awk '{print $2}'); do
             if [[ ! " ${assigned_pids[@]} " =~ " ${pid} " ]]; then
               [[ $sleep_time -gt 200 ]] && sleep_time=$((sleep_time - 36))
               [[ $sleep_time -gt 90 ]]  && sleep_time=$((sleep_time - 9))
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
        if enableFocusCheck {
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
                    sleep_time=$((sleep_time - 7))
                  fi
                  if [[ $sleep_time -gt 15 ]]; then
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
                output += str
            }
        }

        do {
            try newProcess.run()
            isRunning = true
        } catch {
            DispatchQueue.main.async {
                output = "启动脚本失败：\(error)"
            }
        }
    }

    private func stopScript() {
        isRunning = false
        process?.terminate()
        process = nil

        pipe?.fileHandleForReading.readabilityHandler = nil
        pipe = nil

        output += "\n[脚本已停止]\n"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
