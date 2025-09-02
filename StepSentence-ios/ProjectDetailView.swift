import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project

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
                    NavigationLink(destination: PracticeView(sentence: sentence, project: project)) {
                        HStack {
                            Text(sentence.text)
                            Spacer()
                            Circle()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(colorForStatus(sentence.status))
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("项目蓝图")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if project.completedCount == project.totalCount && project.totalCount > 0 {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: SynthesisView(project: project)) {
                        Text("合成作品")
                    }
                }
            }
        }
        .onAppear {
            print("[ProjectDetailView] Appear for project: \(project.title), sentences: \(project.sentences.count)")
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    
    let project = Project(title: "奥巴马演讲", fullText: "我的同胞们，我今天站在这里，为我们面前的艰巨任务而感到谦卑。感谢你们对我的信任，也铭记我们的祖先所付出的牺牲。")
    project.sentences = [
        Sentence(order: 0, text: "我的同胞们，我今天站在这里，为我们面前的艰巨任务而感到谦卑。", status: .approved, project: project),
        Sentence(order: 1, text: "感谢你们对我的信任，也铭记我们的祖先所付出的牺牲。", status: .notStarted, project: project)
    ]
    
    return NavigationStack {
        ProjectDetailView(project: project)
            .modelContainer(container)
    }
}
