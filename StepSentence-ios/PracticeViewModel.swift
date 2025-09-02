import SwiftUI
import AVFoundation

@MainActor
@Observable
final class PracticeViewModel {
    var sentence: Sentence
    private var project: Project

    // MARK: - State
    var isPlayingTTS = false
    var isPlayingRecording = false
    var isRecording = false
    var errorMessage: String?
    var userRecordingURL: URL? {
        didSet {
            sentence.audioFileName = userRecordingURL?.lastPathComponent
        }
    }

    // MARK: - Dependencies
    private let recordingManager = RecordingManager.shared
    private let localTTS = LocalTTS.shared
    private let audioPlayback = AudioPlayback.shared

    init(sentence: Sentence, project: Project) {
        self.sentence = sentence
        self.project = project
        
        if let fileName = sentence.audioFileName {
            let url = FileManager.documentsDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                self.userRecordingURL = url
            }
        }
    }

    // MARK: - Public Interface

    func onViewAppear() {
        Task { await recordingManager.requestPermission() }
    }

    func onViewDisappear() {
        Task { await localTTS.stop() }
        audioPlayback.stop()
        if isRecording {
            recordingManager.stopRecording { _ in } // Stop recording without processing result
        }
    }

    func playTTSButtonTapped() {
        errorMessage = nil
        isPlayingTTS = true
        Task {
            do {
                try await localTTS.speak(text: sentence.text, languageCode: "zh-CN")
                await MainActor.run {
                    self.isPlayingTTS = false
                }
            } catch {
                await MainActor.run {
                    self.isPlayingTTS = false
                    self.errorMessage = "播放失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func playUserRecording() {
        guard let userURL = userRecordingURL else { return }
        
        errorMessage = nil
        isPlayingRecording = true
        Task {
            do {
                try await self.playAudio(url: userURL)
                await MainActor.run { self.isPlayingRecording = false }
            } catch {
                await MainActor.run { 
                    self.isPlayingRecording = false
                    self.errorMessage = "播放录音失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    

    func resetPractice() {
        audioPlayback.stop()
        Task { await localTTS.stop() }
        if let url = userRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        userRecordingURL = nil
        sentence.status = .notStarted
    }

    func approveSentence() {
        sentence.status = .approved
    }

    func getNextSentence() -> Sentence? {
        let sortedSentences = project.sentences.sorted { $0.order < $1.order }
        guard let currentIndex = sortedSentences.firstIndex(where: { $0.id == sentence.id }) else {
            return nil
        }
        
        let nextIndex = currentIndex + 1
        if nextIndex < sortedSentences.count {
            return sortedSentences[nextIndex]
        } else {
            return nil
        }
    }

    func reset(for newSentence: Sentence) {
        // Stop any ongoing audio from the previous state
        onViewDisappear()

        // Reset properties for the new sentence
        self.sentence = newSentence
        self.isPlayingTTS = false
        self.isPlayingRecording = false
        self.isRecording = false
        self.userRecordingURL = nil
        
        // Check if the new sentence already has a recording
        if let fileName = sentence.audioFileName {
            let url = FileManager.documentsDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                self.userRecordingURL = url
            }
        }
        
        print("[PracticeViewModel] Reset for new sentence: \(newSentence.text)")
    }

    // MARK: - Private Logic

    private func startRecording() {
        print("[PracticeViewModel] startRecording called.")
        errorMessage = nil
        let newRecordingURL = FileManager.documentsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        do {
            // Reset previous recording if any
            if let oldURL = userRecordingURL {
                try? FileManager.default.removeItem(at: oldURL)
                userRecordingURL = nil
            }
            try recordingManager.startRecording(to: newRecordingURL)
            self.isRecording = true
            print("[PracticeViewModel] State changed to: isRecording = true")
        } catch {
            print("[PracticeViewModel] Error starting recording: \(error)")
            self.errorMessage = "开始录音失败: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        print("[PracticeViewModel] stopRecording called.")
        isRecording = false
        recordingManager.stopRecording { url in
            DispatchQueue.main.async {
                print("[PracticeViewModel] stopRecording completion handler. URL: \(url?.absoluteString ?? "nil")")
                if let url = url {
                    self.userRecordingURL = url
                    self.sentence.status = .recorded
                    print("[PracticeViewModel] Recording finished.")
                } else {
                    self.errorMessage = "录音失败，请重试"
                }
            }
        }
    }
    
    private func playAudio(url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try audioPlayback.play(url: url) {
                    continuation.resume()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
