
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum ProjectSourceType: String, CaseIterable {
    case text = "从文字"
    case file = "从文件"
}

@MainActor
@Observable
final class NewProjectViewModel {
    // MARK: - UI State
    var sourceType: ProjectSourceType = .text
    var title: String = ""
    var bodyText: String = ""
    
    var mp3URL: URL?
    var srtURL: URL?
    
    var error: String?
    var isParsing = false
    var isCreating = false
    
    var showMp3Importer = false
    var showSrtImporter = false
    
    var previewSegments: [(start: Double, end: Double, text: String)] = []

    // MARK: - Computed Properties
    var isReadyToCreate: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch sourceType {
        case .text:
            return !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file:
            return mp3URL != nil && !previewSegments.isEmpty
        }
    }
    
    // MARK: - Public Methods
    
    func handleSrtSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            srtURL = url
            parseSrtFile()
        case .failure(let err):
            error = "选择 SRT 失败: \(err.localizedDescription)"
        }
    }
    
    func handleMp3Selection(urls: [URL]) {
        guard let url = urls.first else { return }
        let ext = url.pathExtension.lowercased()
        guard ext == "mp3" else {
            error = "请选择本地 mp3 文件"
            return
        }
        mp3URL = url
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            title = url.deletingPathExtension().lastPathComponent
        }
    }

    func createProject(context: ModelContext, completion: @escaping () -> Void) {
        guard !isCreating else { return }
        isCreating = true
        error = nil

        switch sourceType {
        case .text:
            createTextProject(context: context)
        case .file:
            createFileProject(context: context)
        }
        
        isCreating = false
        completion()
    }
    
    func cleanup() {
        if let url = srtURL, url.startAccessingSecurityScopedResource() {
            url.stopAccessingSecurityScopedResource()
        }
        if let url = mp3URL, url.startAccessingSecurityScopedResource() {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - Private Helpers
    
    private func parseSrtFile() {
        guard let srtURL = srtURL else { return }
        isParsing = true
        error = nil
        
        Task {
            do {
                let needsAccess = srtURL.startAccessingSecurityScopedResource()
                defer { if needsAccess { srtURL.stopAccessingSecurityScopedResource() } }
                
                let parsedCues = try SubtitleSegmenter.parse(url: srtURL)
                let mergedSegments = SubtitleSegmenter.mergeCuesToSegments(parsedCues)
                
                await MainActor.run {
                    self.previewSegments = mergedSegments.map { ($0.start, $0.end, $0.text) }
                    self.isParsing = false
                }
            } catch {
                await MainActor.run {
                    self.error = "解析 SRT 失败: \(error.localizedDescription)"
                    self.isParsing = false
                }
            }
        }
    }
    
    private func createTextProject(context: ModelContext) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedText = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newProject = Project(title: trimmedTitle, fullText: trimmedText)
        
        var sentences: [String] = []
        trimmedText.enumerateSubstrings(in: trimmedText.startIndex..<trimmedText.endIndex, options: .bySentences) { (substring, _, _, _) in
            if let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                sentences.append(sentence)
            }
        }
        
        newProject.sentences = sentences.enumerated().map { index, sentenceText in
            Sentence(order: index, text: sentenceText, project: newProject)
        }
        
        context.insert(newProject)
        try? context.save()
    }
    
    private func createFileProject(context: ModelContext) {
        guard let mp3URL = mp3URL, !previewSegments.isEmpty else {
            error = "请先选择 MP3 和 SRT 文件"
            return
        }

        let destMp3Name = uniqueFileName(base: mp3URL.deletingPathExtension().lastPathComponent, ext: mp3URL.pathExtension)
        let destMp3URL = FileManager.documentsDirectory.appendingPathComponent(destMp3Name)
        
        let needsAccess = mp3URL.startAccessingSecurityScopedResource()
        defer { if needsAccess { mp3URL.stopAccessingSecurityScopedResource() } }
        
        do {
            try? FileManager.default.removeItem(at: destMp3URL)
            try FileManager.default.copyItem(at: mp3URL, to: destMp3URL)
        } catch {
            self.error = "拷贝 MP3 文件失败: \(error.localizedDescription)"
            return
        }

        let project = Project(
            title: title.trimmingCharacters(in: .whitespaces),
            fullText: previewSegments.map { $0.text }.joined(separator: "\n"),
            sourceAudioFileName: destMp3Name
        )
        
        project.sentences = previewSegments.enumerated().map { idx, seg in
            Sentence(order: idx, text: seg.text, status: .notStarted, startTimeSec: seg.start, endTimeSec: seg.end, project: project)
        }
        
        context.insert(project)
        try? context.save()
    }
    
    private func uniqueFileName(base: String, ext: String) -> String {
        let safeBase = base.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let stamp = Int(Date().timeIntervalSince1970)
        return "\(safeBase)_\(stamp).\(ext)"
    }
}
