import Foundation
import AVFoundation

final class AudioPlayback: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayback()
    private var player: AVAudioPlayer?
    private var completionHandler: (() -> Void)?

    // Read-only playback state for progress UI
    var isPlaying: Bool { player?.isPlaying ?? false }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }

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

    func play(url: URL, startAt: TimeInterval, completion: (() -> Void)? = nil) throws {
        // Stop any existing playback before starting a new one
        stop()
        
        self.completionHandler = completion
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true)
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        if let player {
            let clamped = max(0, min(startAt, player.duration))
            player.currentTime = clamped
            player.play()
        }
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
