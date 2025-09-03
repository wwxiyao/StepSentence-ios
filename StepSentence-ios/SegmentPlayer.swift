import Foundation
import AVFoundation

final class SegmentPlayer {
    private let player = AVPlayer()
    private var boundaryObserver: Any?
    private var periodicObserver: Any?
    private let queue = DispatchQueue.main
    private var loadedURL: URL?

    // Tunables
    var endGuardSec: Double = 0.02
    var periodicIntervalSec: Double = 0.15
    var seekToleranceSec: Double = 0.02

    // State
    private(set) var currentSegmentID: String?
    var onSegmentStart: ((String) -> Void)?
    var onSegmentEnd: ((String) -> Void)?
    var onProgress: ((String, CMTime) -> Void)?

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
    }

    func load(url: URL) {
        removeObservers()
        let t0 = Date()
        print("[SegmentPlayer] load start url=\(url.lastPathComponent)")
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        loadedURL = url
        let dt = Date().timeIntervalSince(t0)
        print("[SegmentPlayer] load done in \(String(format: "%.3f", dt))s")
    }

    func ensureLoaded(url: URL) {
        if loadedURL != url {
            load(url: url)
        }
    }

    func playSegment(id: String, start: Double, end: Double) {
        currentSegmentID = id
        resetBoundaryObserver(forStart: start, end: end, id: id)
        addPeriodicObserverIfNeeded()
        let tol = CMTime(seconds: seekToleranceSec, preferredTimescale: 600)
        print("[SegmentPlayer] playSegment id=\(id.prefix(6)) start=\(start) end=\(end)")
        player.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: tol, toleranceAfter: tol) { [weak self] _ in
            guard let self, self.currentSegmentID == id else { return }
            self.onSegmentStart?(id)
            self.player.play()
        }
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.pause()
        player.seek(to: .zero)
        currentSegmentID = nil
        removeObservers()
    }

    private func resetBoundaryObserver(forStart start: Double, end: Double, id: String) {
        removeBoundaryObserver()
        let guardTime = CMTime(seconds: endGuardSec, preferredTimescale: 600)
        let endBoundary = max(start, end - guardTime.seconds)
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTime(seconds: endBoundary, preferredTimescale: 600))], queue: queue) { [weak self] in
            guard let self, self.currentSegmentID == id else { return }
            self.player.pause()
            self.onSegmentEnd?(id)
        }
    }

    private func addPeriodicObserverIfNeeded() {
        if periodicObserver != nil { return }
        let interval = CMTime(seconds: periodicIntervalSec, preferredTimescale: 600)
        periodicObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: queue) { [weak self] time in
            guard let self = self, let id = self.currentSegmentID else { return }
            self.onProgress?(id, time)
        }
    }

    private func removeBoundaryObserver() {
        if let obs = boundaryObserver { player.removeTimeObserver(obs); boundaryObserver = nil }
    }

    private func removePeriodicObserver() {
        if let obs = periodicObserver { player.removeTimeObserver(obs); periodicObserver = nil }
    }

    private func removeObservers() { removeBoundaryObserver(); removePeriodicObserver() }
}
