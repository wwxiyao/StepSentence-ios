import SwiftUI
import SwiftData

struct SwiftDataTestView: View {
    @Environment(\.modelContext) private var context
    @State private var projects: [Project] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    Text("加载中...")
                        .font(.title)
                } else {
                    List {
                        ForEach(projects) { project in
                            NavigationLink(destination: SimpleProjectDetailView(project: project)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.title).font(.headline)
                                    Text("\(project.completedCount)/\(project.totalCount) 句已完成")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("SwiftData 测试")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("添加测试项目") {
                        addTestProject()
                    }
                }
            }
        }
        .onAppear {
            loadProjects()
        }
    }
    
    private func loadProjects() {
        print("[SwiftDataTestView] 开始加载项目")
        isLoading = true
        
        do {
            let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            projects = try context.fetch(descriptor)
            print("[SwiftDataTestView] 成功加载 \(projects.count) 个项目")
        } catch {
            print("[SwiftDataTestView] 加载项目失败: \(error)")
            projects = []
        }
        
        isLoading = false
    }
    
    private func addTestProject() {
        print("[SwiftDataTestView] 添加测试项目")
        let testProject = Project(title: "SwiftData测试项目", fullText: "这是一个测试句子。")
        testProject.sentences = [Sentence(order: 0, text: "这是一个测试句子。", project: testProject)]
        
        context.insert(testProject)
        
        do {
            try context.save()
            print("[SwiftDataTestView] 项目保存成功")
            loadProjects() // 重新加载
        } catch {
            print("[SwiftDataTestView] 保存失败: \(error)")
        }
    }
    
    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            context.delete(projects[idx])
        }
        try? context.save()
        loadProjects()
    }
}

#Preview {
    SwiftDataTestView()
        .modelContainer(for: [Project.self, Sentence.self], inMemory: true)
}
