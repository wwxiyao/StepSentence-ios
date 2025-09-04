import SwiftUI
import SwiftData
import UIKit

struct PracticeView: View {
    let project: Project
    let sortedSentences: [Sentence]
    let segmentPlayer: SegmentPlayer
    
    @State private var viewModel: PracticeViewModel
    @State private var errorMessage: String?
    @State private var isInitializing = true
    @State private var ttsSelectedVoiceId: String = LocalTTS.shared.preferredVoiceId ?? LocalTTS.evanId
    @State private var isEditingTimestamp = false // New state to control editing mode
    
    @Environment(\.dismiss) private var dismiss

    init(initialSentence: Sentence, project: Project, sortedSentences: [Sentence], segmentPlayer: SegmentPlayer) {
        self.project = project
        self.sortedSentences = sortedSentences
        self.segmentPlayer = segmentPlayer
        
        let vm = PracticeViewModel(sentence: initialSentence, project: project, sortedSentences: sortedSentences, segmentPlayer: segmentPlayer)
        _viewModel = State(initialValue: vm)
    }
    
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
                practiceInterface(for: viewModel)
            }
        }
        .navigationTitle("单句朗读")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: { viewModel.onViewAppear() })
        .onDisappear {
            viewModel.onViewDisappear()
        }
        .onChange(of: viewModel.sentence.id) { oldValue, newValue in
            print("[PracticeView] sentence.id changed: \(oldValue) -> \(newValue)")
        }
        .onChange(of: viewModel.userRecordingURL) { _, newValue in
            print("[PracticeView] userRecordingURL changed: \(newValue?.lastPathComponent ?? "nil")")
        }
    }
    
    @ViewBuilder
    private func practiceInterface(for vm: PracticeViewModel) -> some View {
        VStack {
            Spacer()
            sentenceCard(for: vm, selectedVoiceId: $ttsSelectedVoiceId)
            Spacer()

            // Missing voice guidance (outside the card)
            MissingVoiceNotice(selectedVoiceId: $ttsSelectedVoiceId)
                .padding(.bottom, 8)
            
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
    private func sentenceCard(for vm: PracticeViewModel, selectedVoiceId: Binding<String>) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Text(vm.sentence.text)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                // Extra top padding to avoid overlap with the inline picker
                .padding(EdgeInsets(top: 70, leading: 30, bottom: 120, trailing: 30))
                .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
                .background(cardBackgroundColor)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditingTimestamp {
                        isEditingTimestamp = false
                    }
                }
                // Inline voice picker at the top inside the card
                .overlay(alignment: .topLeading) {
                    if project.sourceAudioURL == nil {
                        VoicePickerInline(selectedVoiceId: selectedVoiceId)
                            .padding([.top, .leading], 12)
                    } else {
                        TimestampView(sentence: vm.sentence, isEditing: $isEditingTimestamp) {
                            // This is the onCommit callback
                            viewModel.saveContext()
                        }
                        .padding([.top, .leading], 12)
                    }
                }
            
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
                        print("[PracticeView] Approve tapped for id=\(vm.sentence.id)")
                        vm.approveSentence()
                        let next = vm.getNextSentence()
                        print("[PracticeView] Next sentence id=\(next?.id.uuidString ?? "nil")")
                        if let nextSentence = next {
                            vm.switchTo(newSentence: nextSentence)
                        } else {
                            print("[PracticeView] No next sentence. Dismissing view.")
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

    // MARK: - Inline voice picker inside the card
    private struct VoicePickerInline: View {
        @Binding var selectedVoiceId: String
        var body: some View {
            Picker("TTS Voice", selection: $selectedVoiceId) {
                Text("女声").tag(LocalTTS.avaId)
                Text("男声").tag(LocalTTS.evanId)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(maxWidth: 160, alignment: .leading)
            .onChange(of: selectedVoiceId) { _, newValue in
                LocalTTS.shared.preferredVoiceId = newValue
            }
        }
    }

    // MARK: - Missing voice notice (below the card)
    private struct MissingVoiceNotice: View {
        @Binding var selectedVoiceId: String
        var body: some View {
            if !LocalTTS.shared.isVoiceAvailable(identifier: selectedVoiceId) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("未安装所选语音，请前往 设置 > 辅助功能 > 朗读内容 > 声音 > 英语 下载对应语音。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        #if DEBUG
                        Button("打开安装页面") { openDeepSettingsEnglishVoices() }
                            .buttonStyle(.bordered)
                        #endif
                        Button("打开App设置") { openAppSettings() }
                            .buttonStyle(.bordered)
                        Button("我已安装好") { recheckAndSelectAvailable() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }

        private func recheckAndSelectAvailable() {
            if LocalTTS.shared.isVoiceAvailable(identifier: selectedVoiceId) {
                LocalTTS.shared.preferredVoiceId = selectedVoiceId
                return
            }
            if LocalTTS.shared.isVoiceAvailable(identifier: LocalTTS.evanId) {
                selectedVoiceId = LocalTTS.evanId
            } else if LocalTTS.shared.isVoiceAvailable(identifier: LocalTTS.avaId) {
                selectedVoiceId = LocalTTS.avaId
            }
            LocalTTS.shared.preferredVoiceId = selectedVoiceId
        }

        private func openAppSettings() {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }

        private func openDeepSettingsEnglishVoices() {
            let candidates = [
                "App-Prefs:root=General&path=ACCESSIBILITY/SPEECH/VOICES/English",
                "App-Prefs:root=General&path=ACCESSIBILITY/SPEECH",
                "App-Prefs:root=General&path=ACCESSIBILITY"
            ]
            for s in candidates {
                if let u = URL(string: s) {
                    UIApplication.shared.open(u, options: [:], completionHandler: nil)
                    return
                }
            }
            openAppSettings()
        }
    }
    
    @ViewBuilder
    private func recordingControls(for vm: PracticeViewModel) -> some View {
        // Unified controls: Play (left) + Primary action (right: Record/Stop/Redo)
        HStack(spacing: 16) {
            // Play button (disabled when no recording)
            Button(action: { vm.playUserRecording() }) {
                Image(systemName: "play.fill")
                    .font(.largeTitle)
                    .foregroundColor(primaryColor)
                    .opacity(vm.userRecordingURL == nil ? 0.4 : 1.0)
            }
            .disabled(vm.userRecordingURL == nil || vm.isPlayingRecording)

            // Simple dynamic effect while recording, placed between buttons
            RecordingIndicatorView(isActive: vm.isRecording)

            // Primary action button (single position):
            // - No recording: Record (red)
            // - Recording: Stop (red)
            // - Has recording: Redo -> reset and immediately start recording (orange)
            Button(action: {
                if vm.isRecording {
                    vm.recordButtonTapped() // stops recording
                } else if vm.userRecordingURL != nil {
                    vm.resetPractice(); vm.recordButtonTapped() // redo and start recording
                } else {
                    vm.recordButtonTapped() // start recording
                }
            }) {
                let icon = vm.isRecording ? "stop.fill" : (vm.userRecordingURL == nil ? "mic.fill" : "arrow.trianglehead.clockwise")
                let color = vm.isRecording ? destructiveColor : (vm.userRecordingURL == nil ? destructiveColor : warningColor)
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundColor(color)
            }
            .disabled(vm.isPlayingTTS)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
        .frame(maxWidth: 300)
        .background(cardBackgroundColor)
        .cornerRadius(40)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    // MARK: - Recording Indicator (simple animated bars)
    private struct RecordingIndicatorView: View {
        let isActive: Bool

        private let barCount = 5
        private let barWidth: CGFloat = 3
        private let barHeight: CGFloat = 26
        private let spacing: CGFloat = 4

        var body: some View {
            Group {
                if isActive {
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        HStack(spacing: spacing) {
                            ForEach(0..<barCount, id: \.self) { i in
                                let phase = Double(i) * 0.5
                                let value = 0.35 + 0.65 * abs(sin(t * 2.0 + phase))
                                Capsule(style: .continuous)
                                    .fill(Color.black)
                                    .frame(width: barWidth, height: barHeight)
                                    .scaleEffect(y: value, anchor: .bottom)
                            }
                        }
                        .frame(width: totalWidth, height: barHeight)
                    }
                    .transition(.opacity.combined(with: .scale))
                } else {
                    // Keep layout stable when inactive
                    Color.clear
                        .frame(width: totalWidth, height: barHeight)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .accessibilityHidden(true)
        }

        private var totalWidth: CGFloat {
            CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        }
    }
    
    private func initializeViewModel() {
        // This function is obsolete but kept to avoid breaking the call site immediately.
        // The actual initialization is now in the View's init.
    }
}

// MARK: - Subviews
private extension PracticeView {
    struct TimestampView: View {
        @Bindable var sentence: Sentence
        @Binding var isEditing: Bool
        var onCommit: () -> Void
        
        private let step = 0.1
        
        private func formatTime(_ time: Double) -> String {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
            return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
        }
        
        var body: some View {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
        
        private var displayView: some View {
            Button(action: { isEditing = true }) {
                if let start = sentence.startTimeSec, let end = sentence.endTimeSec {
                    Text("\(formatTime(start)) → \(formatTime(end))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
            }
            .buttonStyle(.plain)
        }
        
        @ViewBuilder
        private var editingView: some View {
            VStack(alignment: .leading, spacing: 2) {
                // Start Time
                timeAdjustmentRow(label: "开始", time: Binding(get: { sentence.startTimeSec ?? 0 }, set: { sentence.startTimeSec = $0 }))
                
                // End Time
                timeAdjustmentRow(label: "结束", time: Binding(get: { sentence.endTimeSec ?? 0 }, set: { sentence.endTimeSec = $0 }))
            }
            .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .onTapGesture { 
                // Stop tap from propagating to the card's background tap gesture
            }
        }
        
        private func timeAdjustmentRow(label: String, time: Binding<Double>) -> some View {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 35, alignment: .leading)
                Text(formatTime(time.wrappedValue))
                    .font(.system(.caption, design: .monospaced))
                
                Button {
                    time.wrappedValue -= step
                    onCommit()
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                
                Button {
                    time.wrappedValue += step
                    onCommit()
                } label: { 
                    Image(systemName: "plus.circle.fill")
                }
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .tint(.secondary)
        }
    }
}

#Preview {
    let project = Project(title: "测试项目", fullText: "这是一个测试句子。")
    let sentence = Sentence(order: 0, text: "这是一个测试句子。", project: project)
    project.sentences = [sentence]
    
    return NavigationStack {
        PracticeView(initialSentence: sentence, project: project, sortedSentences: project.sentences, segmentPlayer: SegmentPlayer())
    }
}
