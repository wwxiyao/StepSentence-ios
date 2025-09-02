import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @State private var projects: [Project] = []
    @State private var isCreatingNewProject = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
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
            .navigationTitle("学习项目")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { 
                        print("[ProjectsView] Plus button tapped")
                        isCreatingNewProject = true 
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新建项目")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("测试") {
                        print("[ProjectsView] Test button tapped")
                        // 创建一个测试项目
                        let testProject = Project(title: "测试项目", fullText: "这是一个测试句子。")
                        testProject.sentences = [Sentence(order: 0, text: "这是一个测试句子。", project: testProject)]
                        projects.append(testProject)
                    }
                }
            }
            .sheet(isPresented: $isCreatingNewProject) {
                CreateProjectView()
            }
        }
        .onAppear {
            print("=== ProjectsView onAppear ===")
            loadProjects()
            print("[ProjectsView] Appear with projects count: \(projects.count)")
            for (index, project) in projects.enumerated() {
                print("[ProjectsView] Project \(index): \(project.title) - \(project.sentences.count) sentences")
            }
            print("=== End ProjectsView onAppear ===")
        }
    }

    private func loadProjects() {
        print("[ProjectsView] Loading projects from SwiftData")
        do {
            let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            projects = try context.fetch(descriptor)
            print("[ProjectsView] Loaded \(projects.count) projects from SwiftData")
        } catch {
            print("[ProjectsView] Error loading projects: \(error)")
            projects = []
        }
    }
    
    private func delete(at offsets: IndexSet) {
        print("[ProjectsView] Delete at offsets: \(Array(offsets))")
        for idx in offsets { 
            context.delete(projects[idx])
            projects.remove(at: idx)
        }
        try? context.save()
    }
}

#Preview {
    ProjectsView()
        .modelContainer(for: [Project.self, Sentence.self], inMemory: true)
}
