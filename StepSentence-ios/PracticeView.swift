import SwiftUI
import SwiftData

struct PracticeView: View {
    let sentence: Sentence
    let project: Project
    
    @State private var viewModel: PracticeViewModel?
    @State private var errorMessage: String?
    @State private var isInitializing = true
    
    @Environment(\.dismiss) private var dismiss
    
    // Color Palette
    private let backgroundColor = Color(.systemGray6)
    private let cardBackgroundColor = Color(.systemBackground)
    private let primaryColor = Color.accentColor
    private let destructiveColor = Color.red
    private let warningColor = Color.orange
    private let successColor = Color.green

    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack {
                if isInitializing {
                    initializationView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let vm = viewModel {
                    practiceInterface(for: vm)
                }
            }
        }
        .navigationTitle("单句练习")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: initializeViewModel)
        .onDisappear {
            viewModel?.onViewDisappear()
        }
    }
    
    @ViewBuilder
    private var initializationView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: primaryColor))
                .scaleEffect(1.5)
            Text("初始化中...")
                .font(.title2)
                .foregroundColor(.secondary)
                .padding()
        }
    }
    
    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(destructiveColor)
            Text("发生错误")
                .font(.title.bold())
                .foregroundColor(.primary)
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func practiceInterface(for vm: PracticeViewModel) -> some View {
        VStack {
            Spacer()
            sentenceCard(for: vm)
            Spacer()
            
            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .foregroundColor(destructiveColor)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            recordingControls(for: vm)
                .padding(.bottom, 30)
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private func sentenceCard(for vm: PracticeViewModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Text(vm.sentence.text)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(EdgeInsets(top: 30, leading: 30, bottom: 120, trailing: 30)) // Increased bottom padding
                .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
                .background(cardBackgroundColor)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            HStack(spacing: 20) {
                // TTS Button
                Button(action: { vm.playTTSButtonTapped() }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.largeTitle) // Increased size
                        .foregroundColor(primaryColor)
                }
                .disabled(vm.isRecording || vm.isPlayingTTS || vm.isPlayingRecording)
                .opacity(vm.isPlayingTTS ? 0.5 : 1.0)
                
                // Approval Button (conditionally)
                if vm.userRecordingURL != nil && !vm.isRecording {
                    Button(action: {
                        vm.approveSentence()
                        if let nextSentence = vm.getNextSentence() {
                            vm.reset(for: nextSentence)
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 44)) // Increased size
                            .foregroundColor(successColor)
                    }
                    .disabled(vm.isPlayingTTS || vm.isPlayingRecording)
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func recordingControls(for vm: PracticeViewModel) -> some View {
        // Combined Recording and Playback Controls
        if vm.userRecordingURL == nil {
            // Record Button
            Button(action: { vm.recordButtonTapped() }) {
                Image(systemName: vm.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 50)) // Increased size
                    .foregroundColor(.white)
                    .frame(width: 90, height: 90) // Increased size
                    .background(vm.isRecording ? destructiveColor : primaryColor)
                    .clipShape(Circle())
                    .shadow(color: primaryColor.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .disabled(vm.isPlayingTTS)
        } else {
            // Playback Menu
            HStack(spacing: 25) {
                // Play
                Button(action: { vm.playUserRecording() }) {
                    Image(systemName: "play.fill")
                        .font(.largeTitle) // Increased size
                        .foregroundColor(primaryColor)
                }
                .disabled(vm.isPlayingRecording)

                // Redo
                Button(action: { vm.resetPractice() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.largeTitle) // Increased size
                        .foregroundColor(warningColor)
                }
                
                // Delete
                Button(action: { vm.resetPractice() }) {
                    Image(systemName: "trash.fill")
                        .font(.largeTitle) // Increased size
                        .foregroundColor(destructiveColor)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 30)
            .background(cardBackgroundColor)
            .cornerRadius(40)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private func initializeViewModel() {
        let vm = PracticeViewModel(sentence: sentence, project: project)
        vm.onViewAppear()
        self.viewModel = vm
        self.isInitializing = false
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
