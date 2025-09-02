
import SwiftUI
import SwiftData

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String = ""
    @State private var text: String = ""

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("项目标题") {
                    TextField("例如：奥巴马就职演讲", text: $title)
                }
                Section("文章内容") {
                    TextEditor(text: $text)
                        .frame(height: 200)
                        .accessibilityLabel("文章内容输入框")
                }
            }
            .navigationTitle("创建新项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("创建") { 
                        print("[CreateProjectView] Create button tapped")
                        createProject() 
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func createProject() {
        print("[CreateProjectView] createProject called with title: '\(title)', text length: \(text.count)")
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedText.isEmpty else { 
            print("[CreateProjectView] Form validation failed - title: '\(trimmedTitle)', text: '\(trimmedText)'")
            return 
        }

        print("[CreateProjectView] Creating project: \(trimmedTitle)")
        let newProject = Project(title: trimmedTitle, fullText: trimmedText)
        
        var sentences: [String] = []
        trimmedText.enumerateSubstrings(in: trimmedText.startIndex..<trimmedText.endIndex, options: .bySentences) { (substring, _, _, _) in
            if let sentence = substring {
                let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSentence.isEmpty {
                    sentences.append(trimmedSentence)
                }
            }
        }

        newProject.sentences = sentences.enumerated().map { index, sentenceText in
            Sentence(order: index, text: sentenceText, project: newProject)
        }
        
        context.insert(newProject)
        dismiss()
    }
}

#Preview {
    CreateProjectView()
        .modelContainer(for: [Project.self, Sentence.self], inMemory: true)
}
