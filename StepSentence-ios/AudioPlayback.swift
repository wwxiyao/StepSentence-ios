import Foundation
import AVFoundation

final class AudioPlayback: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayback()
    private var player: AVAudioPlayer?
    private var completionHandler: (() -> Void)?

    func play(url: URL, completion: (() -> Void)? = nil) throws {
        // Stop any existing playback before starting a new one
        stop()
        
        self.completionHandler = completion
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true)
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        player?.play()
    }
    
    func stop() {
        player?.stop()
        player = nil
        completionHandler?()
        completionHandler = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completionHandler?()
        completionHandler = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

