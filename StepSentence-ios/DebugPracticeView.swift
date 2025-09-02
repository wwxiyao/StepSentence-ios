import SwiftUI
import SwiftData

struct DebugPracticeView: View {
    let sentence: Sentence
    let project: Project
    
    @State private var viewModel: PracticeViewModel?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            if let error = errorMessage {
                Text("错误: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else if let vm = viewModel {
                // 使用原来的 PracticeView 内容
                VStack(spacing: 20) {
                    Spacer()
                    
                    Text(vm.sentence.text)
                        .font(.largeTitle)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Spacer()
                    
                    HStack(spacing: 60) {
                        Button(action: { vm.playTTSButtonTapped() }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.largeTitle)
                        }
                        .disabled(vm.isRecording || vm.isPlaying)

                        Button(action: { vm.recordButtonTapped() }) {
                            Image(systemName: vm.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(vm.isRecording ? .red : .accentColor)
                        }
                        .disabled(vm.isPlaying)
                    }
                    
                    Spacer()
                    
                    if vm.userRecordingURL != nil && !vm.isRecording {
                        HStack(spacing: 40) {
                            Button(action: { vm.resetPractice() }) {
                                Text("重录")
                                    .font(.title2)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            
                            Button(action: { 
                                vm.approveSentence()
                                if let nextSentence = vm.getNextSentence() {
                                    vm.reset(for: nextSentence)
                                }
                            }) {
                                Text("满意")
                                    .font(.title2)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        .padding()
                    }
                }
            } else {
                Text("加载中...")
                    .font(.title)
            }
        }
        .navigationTitle("单句练习")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("[DebugPracticeView] 开始初始化 PracticeViewModel")
            let vm = PracticeViewModel(sentence: sentence, project: project)
            print("[DebugPracticeView] PracticeViewModel 初始化成功")
            viewModel = vm
            vm.onViewAppear()
        }
        .onDisappear {
            viewModel?.onViewDisappear()
        }
    }
}

#Preview {
    let project = Project(title: "测试项目", fullText: "这是一个测试句子。")
    let sentence = Sentence(order: 0, text: "这是一个测试句子。", project: project)
    project.sentences = [sentence]
    
    return NavigationStack {
        DebugPracticeView(sentence: sentence, project: project)
    }
}
