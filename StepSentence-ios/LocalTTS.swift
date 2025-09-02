import Foundation
import AVFoundation

@MainActor
final class LocalTTS: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = LocalTTS()
    private let synth = AVSpeechSynthesizer()
    private var speakCont: CheckedContinuation<Void, Error>?
    private var cancelCont: CheckedContinuation<Void, Never>?
    private var currentUtterance: AVSpeechUtterance?
    private static var didLogVoices = false

    // MARK: - Preferred voice management (Ava/Evan)
    private let preferredVoiceKey = "tts.preferredVoiceId"
    static let avaId = "com.apple.voice.premium.en-US.Ava"
    static let evanId = "com.apple.voice.enhanced.en-US.Evan"
    
    var preferredVoiceId: String? {
        get {
            if let saved = UserDefaults.standard.string(forKey: preferredVoiceKey), isVoiceAvailable(identifier: saved) {
                return saved
            }
            // Fallback: prefer Evan (male), then Ava (female), else nil
            if isVoiceAvailable(identifier: Self.evanId) { return Self.evanId }
            if isVoiceAvailable(identifier: Self.avaId) { return Self.avaId }
            return nil
        }
        set {
            if let id = newValue, isVoiceAvailable(identifier: id) {
                UserDefaults.standard.set(id, forKey: preferredVoiceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: preferredVoiceKey)
            }
        }
    }
    
    func isVoiceAvailable(identifier: String) -> Bool {
        return AVSpeechSynthesisVoice.speechVoices().contains(where: { $0.identifier == identifier })
    }

    // MARK: - Preferred rate management
    private let preferredRateKey = "tts.preferredRate"
    var preferredRate: Float {
        get {
            let stored = UserDefaults.standard.object(forKey: preferredRateKey) as? Double
            let value = Float(stored ?? 0.4)
            return clampRate(value)
        }
        set {
            let v = clampRate(newValue)
            UserDefaults.standard.set(Double(v), forKey: preferredRateKey)
        }
    }
    
    private func clampRate(_ r: Float) -> Float {
        let minR = AVSpeechUtteranceMinimumSpeechRate
        let maxR = AVSpeechUtteranceMaximumSpeechRate
        return max(min(r, maxR), minR)
    }

    private override init() {
        super.init()
        synth.delegate = self
    }

    // MARK: - Voice Discovery
    func logAvailableVoices(languagePrefix: String? = nil, force: Bool = false) {
        if !force, Self.didLogVoices { return }
        let all = AVSpeechSynthesisVoice.speechVoices()
        let voices = all
            .filter { v in
                guard let prefix = languagePrefix, !prefix.isEmpty else { return true }
                return v.language.lowercased().hasPrefix(prefix.lowercased())
            }
            .sorted { (a, b) in
                if a.language == b.language { return a.name < b.name }
                return a.language < b.language
            }
        print("[TTS] ===== Available Voices (\(voices.count))/All (\(all.count)) =====")
        for v in voices {
            let quality: String
            switch v.quality {
            case .enhanced: quality = "enhanced"
            default: quality = "default"
            }
            print("[TTS] name=\(v.name), lang=\(v.language), id=\(v.identifier), quality=\(quality)")
        }
        print("[TTS] ============================================")
        Self.didLogVoices = true
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
        // Prefer explicitly selected voice (Ava/Evan), else fall back to language code
        if let id = preferredVoiceId, let v = AVSpeechSynthesisVoice(identifier: id) {
            utt.voice = v
        } else if let code = languageCode {
            utt.voice = AVSpeechSynthesisVoice(language: code)
        } else {
            // Fallback to en-US to keep English content natural if preferred voices are missing
            utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        // Apply rate: use provided or preferred stored rate
        utt.rate = rate ?? preferredRate
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
