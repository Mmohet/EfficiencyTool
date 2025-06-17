import SwiftUI



struct ContentView: View {
    var output = ""


    @ObservedObject var configObj = AppStorageConfig.config
    let config = AppStorageConfig.config

    @ObservedObject var runnerObj = ScriptRunner.shared
    let runner = ScriptRunner.shared
    
    
    
    var newCustomPattern = ""
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
//            // 默认模式列表
//            GroupBox(label: Text("监控进程模式 (默认):")) {
//                VStack(alignment: .leading) {
//                    ForEach(allPatterns, id: \.self) { pattern in
//                        Toggle(pattern, isOn: Binding(
//                            get: { selectedPatterns[pattern] ?? false },
//                            set: { selectedPatterns[pattern] = $0 }
//                        ))
//                    }
//                }
//                .padding()
//                .frame(width: 200, height: 200)
//            }
          
            // 自定义模式列表
            GroupBox(label: Text("监控进程模式 (自定义):")) {
                VStack(spacing: 8) {
                    HStack {
                        TextField("新模式关键字", text: $configObj.newCustomPattern)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("添加") {
                            let trimmed = configObj.newCustomPattern.trimmingCharacters(in: .whitespacesAndNewlines)
                            var current = configObj.getCustomPatterns()
                            if !trimmed.isEmpty && !current.contains(trimmed) {
                                current.append(trimmed)
                                configObj.setCustomPatterns(current)
                                configObj.newCustomPattern = ""
                            }
                        }
                        .disabled(config.newCustomPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(config.getCustomPatterns(), id: \.self) { pattern in
                                HStack {
                                    Text(pattern)
                                    Spacer()
                                    Button(action: {
                                        var current = config.getCustomPatterns()
                                        current.removeAll { $0 == pattern }
                                        config.setCustomPatterns(current)
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
                .onDisappear {
                    runner.stop()
                }
            }
        }
        .padding()
            
            
            GroupBox(label: Text("高级选项")) {
                Toggle("使用全局搜索替代进程抓取命令", isOn: $configObj.useAltPSCommand)
                    .help(config.altPSWarning)
                    .padding()
                
                Toggle("启用前台检测", isOn: $configObj.enableFocusCheck)
                    .padding(.bottom, 8)
            }
                

            
            .padding(.top, 8)


            // 运行/停止 按钮
        Button(config.isRunning ? "停止脚本" : "运行脚本") {
            config.isRunning ? runnerObj.stop() : runnerObj.start()
            }
            .padding(.vertical, 8)
            // 输出区域
        GroupBox(label: Text("终端输出:")) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output +
                         AppStorageConfig.config.output)
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
                .onChange(of: config.self.output) { _ in
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
            
            .padding()
            .frame(minWidth: 450, minHeight: 200)
        }
    }

        }
//    struct ContentView_Previews: PreviewProvider {
//        
//        static var previews: some View {
//            ContentView()
//        }
//    }

