import SwiftUI



struct ContentView: View {
    // var output = ""


    @ObservedObject private var config = AppStorageConfig.config
    // let config = AppStorageConfig.config

    @ObservedObject private var runner = ScriptRunner.shared
    // let runner = ScriptRunner.shared
    
    
    
    var newCustomPattern = ""
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
//            // 默认模式列表
//            GroupBox(label: Text("监控进程模式 (默认):")) {
//
//            }
          
            // 自定义模式列表
            GroupBox(label: Text("监控进程模式 (自定义):")) {
                VStack(spacing: 8) {
                    HStack {
                        TextField("新模式关键字", text: $config.newCustomPattern)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("添加") {
                            let trimmed = config.newCustomPattern.trimmingCharacters(in: .whitespacesAndNewlines)
                            var current = config.getCustomPatterns()
                            if !trimmed.isEmpty && !current.contains(trimmed) {
                                current.append(trimmed)
                                config.setCustomPatterns(current)
                                config.newCustomPattern = ""
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
//                .onDisappear {
//                    runner.stop()
//                }
            }
        }
        .padding()
            
            
            GroupBox(label: Text("高级选项")) {
                Toggle("使用全局搜索替代进程抓取命令", isOn: $config.useAltPSCommand)
                    .help(config.altPSWarning)
                    .padding()
                
                Toggle("启用前台检测", isOn: $config.enableFocusCheck)
                    .padding(.bottom, 8)
                Toggle("启用均衡模式", isOn: $config.enableBalanceCheck)
                    .padding(.bottom, 8)
                Toggle("启用默认规则", isOn: $config.enableDefaultRules)
                    .padding(.bottom, 8)
            }
                

            
            .padding(.top, 8)


            // 运行/停止 按钮
        Button(config.isRunning ? "停止脚本" : "运行脚本") {
            config.isRunning ? runner.stop() : runner.start()
            // updateMenuToggleText()
            NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
            }
            .padding(.vertical, 8)
            // 输出区域
        GroupBox(label: Text("终端输出:")) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(AppStorageConfig.config.output)
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

