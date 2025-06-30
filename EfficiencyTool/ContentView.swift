import SwiftUI



struct ContentView: View {
    // var output = ""

    // variable file stroed in Variables
    @ObservedObject private var config = AppStorageConfig.config

    // script file, everytime toogle this to run/stop script
    @ObservedObject private var runner = ScriptRunner.shared
    
    // language file, store all text(String) file
    @ObservedObject private var language = Language.config
    
    
    
    var newCustomPattern = ""
    
    var body: some View {

        HStack(alignment: .top, spacing: 8) {
//            // 默认模式列表
//            GroupBox(label: Text("监控进程模式 (默认):")) {
//
//            }
          
            // 自定义模式列表
            GroupBox(label: Text(language.customize_rules)) {
                VStack(spacing: 8) {
                    HStack {
                        TextField(language.new_rule, text: $config.newCustomPattern)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(language.add) {
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
            
            
        GroupBox(label: Text(language.advanced_setting)) {
            Toggle(language.global_search, isOn: $config.useAltPSCommand)
                    .help(config.altPSWarning)
                    .padding()
                
            Toggle(language.use_focus_check, isOn: $config.enableFocusCheck)
                    .padding(.bottom, 8)
            Toggle(language.use_balance_mode, isOn: $config.enableBalanceCheck)
                    .padding(.bottom, 8)
            Toggle(language.use_default_rules, isOn: $config.enableDefaultRules)
                    .padding(.bottom, 8)
            Toggle(language.reverse_performance_core, isOn: $config.enablePerformanceCore)
                    .padding(.bottom, 8)
            }
        GroupBox(label: Text(language.balance_settings)) {

            TextField(language.check_threshold, text: $config.BalanceThreshold.self)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, 0)
            TextField(language.send_threshold, text: $config.CPUThreshold.self)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, 0)

        }
                

            
            .padding(.top, 8)


            // 运行/停止 按钮
        Button(config.isRunning ? language.stop_script : language.run_script) {
            config.isRunning ? runner.stop() : runner.start()

            // updateMenuToggleText()
            NotificationCenter.default.post(name: .scriptStateChanged, object: nil)
            }
            .padding(.vertical, 8)
            // 输出区域
        GroupBox(label: Text(language.console_output)) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(AppStorageConfig.config.output)
                        .padding()
                        .font(.system(.body, design: .monospaced))
                        .id("end")
                    Text(language.end_script_help)
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

