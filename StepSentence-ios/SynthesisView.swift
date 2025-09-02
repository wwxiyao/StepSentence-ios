import SwiftUI
import SwiftData

struct SynthesisView: View {
    let project: Project
    @State private var viewModel: SynthesisViewModel

    @State private var isSynthesizing = false
    @State private var synthesizedAudioURL: URL?
    @State private var errorMessage: String?
    @State private var isPlaying = false

    init(project: Project) {
        self.project = project
        _viewModel = State(initialValue: SynthesisViewModel(project: project))
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text(project.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("你的完整作品")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let url = synthesizedAudioURL {
                VStack(spacing: 20) {
                    Button(action: {
                        isPlaying = true
                        viewModel.playAudio(url: url) { isPlaying = false }
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 80))
                    }
                    .disabled(isPlaying)
                    
                    ShareLink(item: url) {
                        Label("分享作品", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }

            } else {
                Button("开始合成") {
                    Task {
                        isSynthesizing = true
                        errorMessage = nil
                        do {
                            synthesizedAudioURL = try await viewModel.synthesizeAudio()
                        } catch {
                            errorMessage = "合成失败: \(error.localizedDescription)"
                        }
                        isSynthesizing = false
                    }
                }
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .disabled(isSynthesizing)
            }

            if isSynthesizing {
                ProgressView("正在合成音频，请稍候...")
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .navigationTitle("作品成果")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    
    let project = Project(title: "Test Project", fullText: "First. Second.")
    project.sentences = [
        Sentence(order: 0, text: "First.", status: .approved, audioFileName: "test.m4a", project: project),
        Sentence(order: 1, text: "Second.", status: .approved, audioFileName: "test.m4a", project: project)
    ]
    
    return NavigationStack {
        SynthesisView(project: project)
            .modelContainer(container)
    }
}
