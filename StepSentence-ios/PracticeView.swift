import SwiftUI
import SwiftData

struct PracticeView: View {
    let sentence: Sentence
    let project: Project
    
    @State private var viewModel: PracticeViewModel?
    @State private var errorMessage: String?
    @State private var isInitializing = true
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            if isInitializing {
                Text("初始化中...")
                    .font(.title)
            } else if let error = errorMessage {
                VStack {
                    Text("错误")
                        .font(.title)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.body)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if let vm = viewModel {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Text(vm.sentence.text)
                        .font(.largeTitle)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Spacer()
                    
                    // 错误信息显示
                    if let errorMessage = vm.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    // 基本按钮
                    HStack(spacing: 60) {
                        Button(action: { 
                            print("[PracticeView] TTS 按钮点击")
                            vm.playTTSButtonTapped() 
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.largeTitle)
                        }
                        .disabled(vm.isRecording || vm.isPlayingTTS)
                        .opacity(vm.isPlayingTTS ? 0.6 : 1.0)

                        Button(action: { 
                            print("[PracticeView] 录音按钮点击")
                            vm.recordButtonTapped() 
                        }) {
                            Image(systemName: vm.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(vm.isRecording ? .red : .accentColor)
                        }
                        .disabled(vm.isPlayingTTS || vm.isPlayingRecording)
                    }
                    
                    // 录音播放按钮（当有录音时显示）
                    if vm.userRecordingURL != nil && !vm.isRecording {
                        HStack(spacing: 40) {
                            Button(action: { 
                                print("[PracticeView] 播放录音按钮点击")
                                vm.playUserRecording() 
                            }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("播放录音")
                                }
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .disabled(vm.isPlayingRecording)
                            .opacity(vm.isPlayingRecording ? 0.6 : 1.0)
                            
                            Button(action: { 
                                print("[PracticeView] 对比播放按钮点击")
                                vm.playComparison() 
                            }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("对比播放")
                                }
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                            .disabled(vm.isPlayingTTS || vm.isPlayingRecording)
                        }
                    }
                    
                    Spacer()
                    
                    // 评估按钮（当有录音时显示）
                    if vm.userRecordingURL != nil && !vm.isRecording {
                        HStack(spacing: 40) {
                            Button(action: { 
                                print("[PracticeView] 重录按钮点击")
                                vm.resetPractice() 
                            }) {
                                Text("重录")
                                    .font(.title2)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .disabled(vm.isPlayingTTS || vm.isPlayingRecording)
                            
                            Button(action: { 
                                print("[PracticeView] 满意按钮点击")
                                vm.approveSentence()
                                if let nextSentence = vm.getNextSentence() {
                                    vm.reset(for: nextSentence)
                                } else {
                                    dismiss()
                                }
                            }) {
                                Text("满意")
                                    .font(.title2)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(vm.isPlayingTTS || vm.isPlayingRecording)
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("单句练习")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("[PracticeView] 开始初始化")
            initializeViewModel()
        }
        .onDisappear {
            viewModel?.onViewDisappear()
        }
    }
    
    private func initializeViewModel() {
        print("[PracticeView] 创建 PracticeViewModel")
        
        do {
            print("[PracticeView] 步骤1: 创建 ViewModel 实例")
            let vm = PracticeViewModel(sentence: sentence, project: project)
            print("[PracticeView] 步骤2: ViewModel 创建成功")
            
            print("[PracticeView] 步骤3: 调用 onViewAppear")
            vm.onViewAppear()
            print("[PracticeView] 步骤4: onViewAppear 完成")
            
            self.viewModel = vm
            self.isInitializing = false
            print("[PracticeView] 初始化完成")
            
        } catch {
            print("[PracticeView] 初始化失败: \(error)")
            self.errorMessage = "初始化失败: \(error.localizedDescription)"
            self.isInitializing = false
        }
    }
}

#Preview {
    let project = Project(title: "测试项目", fullText: "这是一个测试句子。")
    let sentence = Sentence(order: 0, text: "这是一个测试句子。", project: project)
    project.sentences = [sentence]
    
    return NavigationStack {
        PracticeView(sentence: sentence, project: project)
    }
}
