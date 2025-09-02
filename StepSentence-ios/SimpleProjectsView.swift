import SwiftUI

struct SimpleProjectsView: View {
    @State private var projects: [String] = []
    @State private var isCreatingNewProject = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(projects, id: \.self) { project in
                    NavigationLink(destination: Text("项目详情: \(project)")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project).font(.headline)
                            Text("这是一个测试项目")
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
                        print("[SimpleProjectsView] Plus button tapped")
                        isCreatingNewProject = true 
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新建项目")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("测试") {
                        print("[SimpleProjectsView] Test button tapped")
                        projects.append("测试项目 \(projects.count + 1)")
                    }
                }
            }
            .sheet(isPresented: $isCreatingNewProject) {
                VStack {
                    Text("创建新项目")
                        .font(.title)
                    Button("关闭") {
                        isCreatingNewProject = false
                    }
                }
                .padding()
            }
        }
        .onAppear {
            print("=== SimpleProjectsView onAppear ===")
            print("[SimpleProjectsView] Projects count: \(projects.count)")
        }
    }
    
    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            projects.remove(at: idx)
        }
    }
}

#Preview {
    SimpleProjectsView()
}
