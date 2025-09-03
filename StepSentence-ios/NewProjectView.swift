
import SwiftUI
import UniformTypeIdentifiers

struct NewProjectView: View {
    @State private var viewModel = NewProjectViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("项目来源", selection: $viewModel.sourceType) {
                        ForEach(ProjectSourceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("项目标题") {
                    TextField("例如：奥巴马就职演讲", text: $viewModel.title)
                }

                switch viewModel.sourceType {
                case .text:
                    Section("文章内容") {
                        TextEditor(text: $viewModel.bodyText)
                            .frame(minHeight: 200)
                            .accessibilityLabel("文章内容输入框")
                    }
                case .file:
                    fileImportSection
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("创建新项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isCreating {
                        ProgressView()
                    } else {
                        Button("创建") {
                            viewModel.createProject(context: context) {
                                dismiss()
                            }
                        }
                        .disabled(!viewModel.isReadyToCreate)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showMp3Importer) {
                DocumentPickerView(contentTypes: [.mp3], allowsMultipleSelection: false) { urls in
                    viewModel.handleMp3Selection(urls: urls)
                } onCancel: {}
            }
            .fileImporter(
                isPresented: $viewModel.showSrtImporter,
                allowedContentTypes: srtUTTypes,
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleSrtSelection(result: result)
            }
            .onDisappear {
                viewModel.cleanup()
            }
        }
    }
    
    @ViewBuilder
    private var fileImportSection: some View {
        Section("选择文件") {
            HStack {
                Text("音频 MP3")
                Spacer()
                Button(viewModel.mp3URL == nil ? "选择" : viewModel.mp3URL!.lastPathComponent) {
                    viewModel.showMp3Importer = true
                }
            }
            HStack {
                Text("字幕 SRT")
                Spacer()
                Button(viewModel.srtURL == nil ? "选择" : viewModel.srtURL!.lastPathComponent) {
                    viewModel.showSrtImporter = true
                }
            }
        }

        if viewModel.isParsing {
            Section {
                HStack {
                    ProgressView()
                    Spacer()
                    Text("解析中...")
                    Spacer()
                }
            }
        }

        if !viewModel.previewSegments.isEmpty {
            Section("预览分段 (\(viewModel.previewSegments.count))") {
                List(viewModel.previewSegments.prefix(10), id: \.start) { seg in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(seg.text)
                        Text(String(format: "%.3f → %.3f", seg.start, seg.end))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if viewModel.previewSegments.count > 10 {
                    Text("仅展示前 10 条作为预览")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var srtUTTypes: [UTType] {
        var types: [UTType] = []
        if let srt = UTType(filenameExtension: "srt") { types.append(srt) }
        types.append(.text)
        types.append(.plainText)
        return types
    }
}

#Preview {
    NewProjectView()
        .modelContainer(for: [Project.self, Sentence.self], inMemory: true)
}
