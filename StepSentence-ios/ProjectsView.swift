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
            .navigationTitle("库")
            // 与下面的列表拉开一点点距离
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 8)
            }
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
