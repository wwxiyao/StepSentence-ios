import SwiftUI
import SwiftData

struct PracticeView: View {
    // The project is a stable reference.
    private var project: Project
    
    // The viewModel is the source of truth for the view's state.
    // It's managed as @State because it's a class conforming to Observable.
    @State private var viewModel: PracticeViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    // The view is initialized with the first sentence to practice.
    init(sentence: Sentence, project: Project) {
        self.project = project
        _viewModel = State(initialValue: PracticeViewModel(sentence: sentence, project: project))
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // The displayed text is always from the viewModel's current sentence.
            Text(viewModel.sentence.text)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 60) {
                // Listen Button
                Button(action: { viewModel.playTTSButtonTapped() }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.largeTitle)
                }
                .disabled(viewModel.isRecording || viewModel.isPlaying)

                // Record/Stop Button
                Button(action: { viewModel.recordButtonTapped() }) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(viewModel.isRecording ? .red : .accentColor)
                }
                .disabled(viewModel.isPlaying)
            }
            
            Spacer()
            
            // Evaluation Buttons
            if viewModel.userRecordingURL != nil && !viewModel.isRecording {
                HStack(spacing: 40) {
                    Button(action: { viewModel.resetPractice() }) {
                        Text("重录")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    
                    Button(action: { 
                        viewModel.approveSentence()
                        if let nextSentence = viewModel.getNextSentence() {
                            viewModel.reset(for: nextSentence)
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
                }
                .padding()
            }
        }
        .navigationTitle("单句练习")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onViewAppear() }
        .onDisappear { viewModel.onViewDisappear() }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    
    let project = Project(title: "Test", fullText: "First sentence. Second sentence.")
    let sentence1 = Sentence(order: 0, text: "This is a sentence for practice.", project: project)
    let sentence2 = Sentence(order: 1, text: "Second sentence.", project: project)
    project.sentences = [sentence1, sentence2]
    
    return NavigationStack {
        PracticeView(sentence: sentence1, project: project)
            .modelContainer(container)
    }
}
