import SwiftUI

struct ContentView: View {
    @State private var output = ""
    @State private var isRunning = false
    @State private var process: Process? = nil
    @State private var pipe: Pipe? = nil

    var body: some View {
        VStack(spacing: 12) {
            Button(isRunning ? "停止脚本" : "运行脚本") {
                if isRunning {
                    stopScript()
                } else {
                    startScript()
                }
            }
            .padding(.vertical, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(output)
                        .padding()
                        .font(.system(.body, design: .monospaced))
                        .id("end")
                }
                .onChange(of: output) { _ in
                    // 自动滚动到最新输出
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 350)
    }

    /// 实时启动脚本并读取输出
    private func startScript() {
        output = ""

        let script = """
        #!/bin/bash

        assigned_pids=()
        sleep_time=50
        taskpolicy -b -p $$
        echo "sent $$ bash"
        while true; do
           timestamp=$(date "+%H:%M")
           echo "[$timestamp]"

           for pid in $(ps aux | grep -E 'Renderer|Chrome|Edge|Reading|bilibili|Terminal|wine' | grep -v grep | grep -v GPU | grep -v server | awk '{print $2}'); do
             # If PID is not in the list of assigned PIDs
             if [[ ! " ${assigned_pids[@]} " =~ " ${pid} " ]]; then
               if [[ $sleep_time -gt 200 ]]; then
                 sleep_time=$((sleep_time - 36))
               fi
               if [[ $sleep_time -gt 90 ]]; then
                 sleep_time=$((sleep_time - 9))
               fi
               if [[ $sleep_time -gt 15 ]]; then
                 sleep_time=$((sleep_time - 3))
               fi
              taskpolicy -b -p $pid
              full_path=$(ps -p $pid -o comm=)
              process_name=$(echo "$full_path" | sed -E 's#.*/([^/]*\\.app)/.*MacOS/##')
              echo "Assigned '$process_name' (PID $pid) to efficiency cores"
               # Add the PID to the list of assigned ones
               assigned_pids+=($pid)
             fi
         
         
           done

        ## --- Updated Block for Minecraft/Java Process using ps aux ---
        ## Get the frontmost (active) application.
        #front_app=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true')
        #
        ## Use ps aux to check if any process matching "minecraft" or "java" exists.
        ## This takes the first matching process.
        #process_line=$(ps aux | grep -E 'minecraft|java' | grep -v grep | head -n 1)
        #if [[ -n "$process_line" ]]; then
        #    minecraft_pid=$(echo "$process_line" | awk '{print $2}')
        #    echo "Minecraft/Java process found with PID: $minecraft_pid"
        #    
        #    # Check if the active application is Minecraft or Java
        #    if [[ "$front_app" =~ [Mm]inecraft || "$front_app" =~ [Jj]ava ]]; then
        #         echo "Minecraft/Java is frontmost. Sending PID $minecraft_pid to performance cores."
        #         taskpolicy -B -p "$minecraft_pid"
        #    else
        #         echo "Minecraft/Java is in background. Sending PID $minecraft_pid to efficiency cores."
        #         taskpolicy -b -p "$minecraft_pid"
        #    fi
        #else
        #    echo "No Minecraft/Java process found using ps aux."
        #fi
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
           echo -e "\n\n"
           # Wait for the adjusted sleep time before checking again
           sleep $sleep_time
         done
        """

        let newPipe = Pipe()
        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        newProcess.arguments = ["-c", script]
        newProcess.standardOutput = newPipe
        newProcess.standardError = newPipe

        // 赋值到状态变量，以便后续清理
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

    /// 停止脚本并清理资源
    private func stopScript() {
        isRunning = false
        process?.terminate()
        process = nil
        
        // 取消读取 handler 并关闭管道
        pipe?.fileHandleForReading.readabilityHandler = nil
        pipe = nil
        
        // 可选：输出提示
        output += "\n[脚本已停止]\n"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
