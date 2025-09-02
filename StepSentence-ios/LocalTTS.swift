import Foundation
import AVFoundation

@MainActor
final class LocalTTS: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = LocalTTS()
    private let synth = AVSpeechSynthesizer()
    private var speakCont: CheckedContinuation<Void, Error>?
    private var cancelCont: CheckedContinuation<Void, Never>?
    private var currentUtterance: AVSpeechUtterance?

    private override init() {
        super.init()
        synth.delegate = self
    }

    func speak(text: String, languageCode: String? = nil, rate: Float? = nil) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Ensure no previous speech is active and wait for its cancel callback.
        if synth.isSpeaking {
            await stop()
        }

        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true)

        let utt = AVSpeechUtterance(string: trimmed)
        if let code = languageCode { utt.voice = AVSpeechSynthesisVoice(language: code) }
        if let r = rate { utt.rate = r }
        currentUtterance = utt

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            // Safety: if a previous continuation somehow exists, cancel it to avoid leaks.
            if let prev = self.speakCont { prev.resume(throwing: NSError(domain: "LocalTTS", code: -2, userInfo: [NSLocalizedDescriptionKey: "Previous TTS interrupted"])) }
            self.speakCont = cont
            self.synth.speak(utt)
        }
    }

    func stop() async {
        guard synth.isSpeaking else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            // If there is an active speak continuation, it will be resumed in didCancel.
            self.cancelCont = cont
            _ = self.synth.stopSpeaking(at: .immediate)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if utterance == currentUtterance {
                speakCont?.resume(returning: ())
                speakCont = nil
                currentUtterance = nil
            }
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if utterance == currentUtterance {
                speakCont?.resume(throwing: NSError(domain: "LocalTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "TTS cancelled"]))
                speakCont = nil
                currentUtterance = nil
            }
            cancelCont?.resume(returning: ())
            cancelCont = nil
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }
}
