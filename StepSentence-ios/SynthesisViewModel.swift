import Foundation
import AVFoundation

@Observable
final class SynthesisViewModel {
    let project: Project
    private let audioPlayback = AudioPlayback.shared

    init(project: Project) {
        self.project = project
    }

    func synthesizeAudio() async throws -> URL {
        let composition = AVMutableComposition()
        var insertAt = CMTime.zero

        let sortedSentences = project.sentences.sorted { $0.order < $1.order }

        for sentence in sortedSentences {
            guard let audioURL = sentence.audioURL, FileManager.default.fileExists(atPath: audioURL.path) else {
                throw SynthesisError.missingRecording(sentence.text)
            }
            
            let asset = AVURLAsset(url: audioURL)
                        let assetTimeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
            
            // Add a small gap between sentences for better pacing
            let gapDuration = CMTime(seconds: 0.2, preferredTimescale: assetTimeRange.duration.timescale)
            
            try await composition.insertTimeRange(assetTimeRange, of: asset, at: insertAt)
            insertAt = CMTimeAdd(insertAt, assetTimeRange.duration)
            composition.insertEmptyTimeRange(CMTimeRange(start: insertAt, duration: gapDuration))
            insertAt = CMTimeAdd(insertAt, gapDuration)
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw SynthesisError.exportFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(project.title.filter { $0.isLetter || $0.isNumber })_synthesis")
            .appendingPathExtension("m4a")
        
        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
            return outputURL
        } catch {
            throw error
        }
    }
    
    func playAudio(url: URL, completion: @escaping () -> Void) {
        do {
            try audioPlayback.play(url: url, completion: completion)
        } catch {
            print("Playback failed: \(error)\n")
            completion()
        }
    }
    
    func playSynthesizedAudio(completion: @escaping () -> Void) {
        // This method will be called from the view when playing synthesized audio
        // The actual audio URL will be passed from the view
        completion()
    }
}

enum SynthesisError: Error, LocalizedError {
    case missingRecording(String)
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .missingRecording(let text):
            return "句子 \"\(text)\" 缺少录音。"
        case .exportFailed:
            return "导出合成音频失败。"
        }
    }
}
