import Foundation
import AVFoundation

final class RecordingManager: NSObject, AVAudioRecorderDelegate {
    static let shared = RecordingManager()
    private var recorder: AVAudioRecorder?
    private var recordingDidFinish: ((URL?) -> Void)?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { ok in
                cont.resume(returning: ok)
            }
        }
    }

    func startRecording(to url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.record()
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        print("[RecordingManager] stopRecording called.")
        self.recordingDidFinish = completion
        recorder?.stop()
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("[RecordingManager] audioRecorderDidFinishRecording called with success: \(flag)")
        let url = flag ? recorder.url : nil
        recordingDidFinish?(url)
        recordingDidFinish = nil
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

