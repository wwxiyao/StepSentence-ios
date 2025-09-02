import SwiftUI

struct SimpleProjectDetailView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(project.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                ProgressView(value: Double(project.completedCount), total: Double(project.totalCount)) {
                    HStack {
                        Text("进度")
                        Spacer()
                        Text("\(project.completedCount)/\(project.totalCount)")
                    }
                }
                .tint(.green)
            }
            .padding(.horizontal)

            List {
                ForEach(project.sentences.sorted(by: { $0.order < $1.order })) { sentence in
                    NavigationLink(destination: DebugPracticeView(sentence: sentence, project: project)) {
                        HStack {
                            Text(sentence.text)
                            Spacer()
                            Circle()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(colorForStatus(sentence.status))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("项目蓝图")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("[SimpleProjectDetailView] Appear for project: \(project.title), sentences: \(project.sentences.count)")
        }
    }
    
    private func colorForStatus(_ status: SentenceStatus) -> Color {
        switch status {
        case .notStarted:
            return .gray.opacity(0.5)
        case .recorded, .needsReview:
            return .orange
        case .approved:
            return .green
        }
    }
}

#Preview {
    let project = Project(title: "测试项目", fullText: "这是一个测试句子。")
    project.sentences = [Sentence(order: 0, text: "这是一个测试句子。", project: project)]
    
    return NavigationStack {
        SimpleProjectDetailView(project: project)
    }
}
