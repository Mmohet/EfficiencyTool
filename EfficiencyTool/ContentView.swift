import SwiftUI

struct ContentView: View {
    @AppStorage("customPatterns") private var customPatternsString: String = ""
    private func getCustomPatterns() -> [String] {
        customPatternsString.isEmpty ? [] : customPatternsString.components(separatedBy: ",")
    }

    private func setCustomPatterns(_ patterns: [String]) {
        customPatternsString = patterns.joined(separator: ",")
    }

    @State private var newCustomPattern: String = ""

    @State private var useAltPSCommand = false
    private let altPSWarning = "⚠️ 启用此选项将完全替代默认的进程筛选命令，会将整个系统进程都放入小核, 建议仅在必要时使用。"
    
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
        HStack(alignment: .top, spacing: 16) {
            // 默认模式列表
            GroupBox(label: Text("监控进程模式 (默认):")) {
                VStack(alignment: .leading) {
                    ForEach(allPatterns, id: \.self) { pattern in
                        Toggle(pattern, isOn: Binding(
                            get: { selectedPatterns[pattern] ?? false },
                            set: { selectedPatterns[pattern] = $0 }
                        ))
                    }
                }
                .padding()
                .frame(width: 200, height: 200)
            }
          
            // 自定义模式列表
            GroupBox(label: Text("监控进程模式 (自定义):")) {
                VStack(spacing: 8) {
                    HStack {
                        TextField("新模式关键字", text: $newCustomPattern)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("添加") {
                            let trimmed = newCustomPattern.trimmingCharacters(in: .whitespacesAndNewlines)
                            var current = getCustomPatterns()
                            guard !trimmed.isEmpty, !current.contains(trimmed) else { return }
                            current.append(trimmed)
                            setCustomPatterns(current)
                            newCustomPattern = ""
                        }
                        .disabled(newCustomPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(getCustomPatterns(), id: \.self) { pattern in
                                HStack {
                                    Text(pattern)
                                    Spacer()
                                    Button(action: {
                                        var current = getCustomPatterns()
                                        current.removeAll { $0 == pattern }
                                        setCustomPatterns(current)
                                    }) {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }

                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding()
                .frame(width: 200, height: 200)
            }
        }
        .padding()
            
            
            GroupBox(label: Text("高级选项")) {
                Toggle("使用全局搜索替代进程抓取命令", isOn: $useAltPSCommand)
                    .help(altPSWarning)
                    .padding()
                
                Toggle("启用前台检测", isOn: $enableFocusCheck)
                    .padding(.bottom, 8)
            }
                

            
            .padding(.top, 8)


            // 运行/停止 按钮
            Button(isRunning ? "停止脚本" : "运行脚本") {
                isRunning ? stopScript() : startScript()
            }
            .padding(.vertical, 8)

            // 输出区域
        GroupBox(label: Text("终端输出:")) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output)
                        .padding()
                        .font(.system(.body, design: .monospaced))
                        .id("end")
                    Text("如果想取消效果则关闭脚本并退出生效的应用并重进即可，对于全局搜索则重启即可")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .opacity(0.8)
                        .padding(.top, 8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                .onChange(of: output) { _ in
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
            
            .padding()
            .frame(minWidth: 450, minHeight: 200)
        }
    }

    private func startScript() {
        output = ""

        let psCommand: String
        if useAltPSCommand {
            psCommand = """
ps aux | grep -v grep | grep -v GPU | awk '$1!="root" && $1!="Apple" && $1 !~ /^_/{ print $2 }'
"""
        } else {
            let defaultPatterns = allPatterns
                .filter { selectedPatterns[$0] == true }
            let combined = defaultPatterns + getCustomPatterns()
            let regex = combined
                .joined(separator: "|")
            psCommand = "ps aux | grep -E '\(regex)' | grep -v grep | grep -v GPU | grep -v server | awk '{print $2}'"
        }
        
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
           for pid in $(\(psCommand)); do
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
