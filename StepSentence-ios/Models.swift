import Foundation
import SwiftData

enum SentenceStatus: String, Codable, CaseIterable {
    case notStarted
    case recorded
    case needsReview
    case approved
}

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var fullText: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Sentence.project)
    var sentences: [Sentence]

    init(title: String, fullText: String, sentences: [Sentence] = []) {
        self.id = UUID()
        self.title = title
        self.fullText = fullText
        self.createdAt = Date()
        self.sentences = sentences
    }

    var completedCount: Int { sentences.filter { $0.status == .approved }.count }
    var totalCount: Int { sentences.count }
}

extension Project: Hashable {
    static func == (lhs: Project, rhs: Project) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@Model
final class Sentence {
    @Attribute(.unique) var id: UUID
    var order: Int
    var text: String
    // Persist enum as raw string for forward compatibility
    private var statusStorage: String
    var audioFileName: String?

    @Relationship var project: Project?

    init(order: Int, text: String, status: SentenceStatus = .notStarted, audioFileName: String? = nil, project: Project? = nil) {
        self.id = UUID()
        self.order = order
        self.text = text
        self.statusStorage = status.rawValue
        self.audioFileName = audioFileName
        self.project = project
    }

    var status: SentenceStatus {
        get { SentenceStatus(rawValue: statusStorage) ?? .notStarted }
        set { statusStorage = newValue.rawValue }
    }

    var isRecorded: Bool { audioFileName != nil }
    var audioURL: URL? {
        guard let name = audioFileName else { return nil }
        return FileManager.documentsDirectory.appendingPathComponent(name)
    }
}

extension FileManager {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
