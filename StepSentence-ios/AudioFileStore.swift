import Foundation

enum AudioFileStore {
    static let baseFolder = "Recordings"

    static func relativePath(projectID: UUID, sentenceID: UUID, ext: String = "m4a") -> String {
        "\(baseFolder)/\(projectID.uuidString)/\(sentenceID.uuidString).\(ext)"
    }

    static func ensureDirectoryExists(for projectID: UUID) throws {
        let dir = FileManager.documentsDirectory
            .appendingPathComponent(baseFolder)
            .appendingPathComponent(projectID.uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    static func absoluteURL(forRelative path: String) -> URL {
        FileManager.documentsDirectory.appendingPathComponent(path)
    }
}

