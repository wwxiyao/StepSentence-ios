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
    // Optional source audio for time-aligned projects (e.g., imported MP3+SRT)
    var sourceAudioFileName: String?
    @Relationship(deleteRule: .cascade, inverse: \Sentence.project)
    var sentences: [Sentence]

    init(title: String, fullText: String, sourceAudioFileName: String? = nil, sentences: [Sentence] = []) {
        self.id = UUID()
        self.title = title
        self.fullText = fullText
        self.createdAt = Date()
        self.sourceAudioFileName = sourceAudioFileName
        self.sentences = sentences
    }

    var completedCount: Int { sentences.filter { $0.status == .approved }.count }
    var totalCount: Int { sentences.count }

    var sourceAudioURL: URL? {
        guard let name = sourceAudioFileName else { return nil }
        return FileManager.documentsDirectory.appendingPathComponent(name)
    }
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
    // Optional time-aligned segment within the project's source audio
    var startTimeSec: Double?
    var endTimeSec: Double?

    @Relationship var project: Project?

    init(order: Int, text: String, status: SentenceStatus = .notStarted, audioFileName: String? = nil, startTimeSec: Double? = nil, endTimeSec: Double? = nil, project: Project? = nil) {
        self.id = UUID()
        self.order = order
        self.text = text
        self.statusStorage = status.rawValue
        self.audioFileName = audioFileName
        self.startTimeSec = startTimeSec
        self.endTimeSec = endTimeSec
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

    var hasTiming: Bool { startTimeSec != nil && endTimeSec != nil }
}

extension FileManager {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
