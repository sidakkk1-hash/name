import Foundation
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - NativeAudioEngineDelegate
public protocol NativeAudioEngineDelegate: AnyObject, Sendable {
    func nativeAudioEngineDidReady()
    func nativeAudioEngineDidChangeState(isPlaying: Bool, isLoading: Bool)
    func nativeAudioEngineDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval)
    func nativeAudioEngineDidEnd()
    func nativeAudioEngineDidFail(error: String)
}

// MARK: - NativeAudioEngine
/// Native AVPlayer-based background audio playback engine.
/// Runs alongside WKAudioEngine, delivering seamless background playback,
/// Lock Screen controls, Control Center scrubbing, and Dynamic Island integration.
@MainActor
public final class NativeAudioEngine: NSObject, @unchecked Sendable {
    public static let shared = NativeAudioEngine()
    
    public weak var delegate: NativeAudioEngineDelegate?
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    
    public private(set) var isReady: Bool = false
    public private(set) var currentSong: Song?
    
    override public init() {
        super.init()
    }
    
    // MARK: - Load and Play
    public func loadAndPlay(song: Song) async -> Bool {
        self.currentSong = song
        self.isReady = false
        
        let videoId = song.id
        print("[NativeAudioEngine] Resolving stream for videoId: \(videoId)")
        
        do {
            let stream = try await StreamResolutionService.shared.resolveStream(for: song)
            let host = stream.url.host ?? "unknown"
            let mime = stream.mimeType ?? "unknown"
            
            print("""
            [NativeAudioEngine] Stream Resolved:
              videoId: \(videoId)
              resolved URL host: \(host)
              mime type: \(mime)
              isHLS: \(stream.isHLS)
            """)
            
            // Build AVURLAsset with HTTP headers if provided
            let asset: AVURLAsset
            if let headers = stream.headers, !headers.isEmpty {
                asset = AVURLAsset(url: stream.url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            } else {
                asset = AVURLAsset(url: stream.url)
            }
            
            // Cleanup previous player item
            cleanupPlayer()
            
            let item = AVPlayerItem(asset: asset)
            self.playerItem = item
            
            let p = AVPlayer(playerItem: item)
            p.automaticallyWaitsToMinimizeStalling = true
            self.player = p
            
            setupObservers(for: item, player: p)
            return true
        } catch {
            print("[NativeAudioEngine] Stream resolution failed for \(videoId):", error)
            delegate?.nativeAudioEngineDidFail(error: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Observers
    private func setupObservers(for item: AVPlayerItem, player: AVPlayer) {
        // Observe PlayerItem Status
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("""
                [NativeAudioEngine] AVPlayerItem.status: \(observedItem.status.rawValue)
                [NativeAudioEngine] AVPlayerItem.error: \(String(describing: observedItem.error))
                """)
                
                switch observedItem.status {
                case .readyToPlay:
                    self.isReady = true
                    print("""
                    [NativeAudioEngine] readyToPlay reached!
                    [NativeAudioEngine] player.timeControlStatus: \(player.timeControlStatus.rawValue)
                    [NativeAudioEngine] player.reasonForWaitingToPlay: \(String(describing: player.reasonForWaitingToPlay))
                    """)
                    player.play()
                    self.delegate?.nativeAudioEngineDidReady()
                    self.delegate?.nativeAudioEngineDidChangeState(isPlaying: true, isLoading: false)
                    
                case .failed:
                    self.isReady = false
                    let err = observedItem.error?.localizedDescription ?? "AVPlayerItem playback failed"
                    print("[NativeAudioEngine] Playback failed: \(err)")
                    self.delegate?.nativeAudioEngineDidFail(error: err)
                    
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        // Observe TimeControlStatus
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] observedPlayer, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let isPlaying = observedPlayer.timeControlStatus == .playing
                let isLoading = observedPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate
                print("""
                [NativeAudioEngine] timeControlStatus changed: \(observedPlayer.timeControlStatus.rawValue)
                [NativeAudioEngine] reasonForWaitingToPlay: \(String(describing: observedPlayer.reasonForWaitingToPlay))
                """)
                self.delegate?.nativeAudioEngineDidChangeState(isPlaying: isPlaying, isLoading: isLoading)
            }
        }
        
        // Periodic Time Observer (every 0.5 seconds)
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self, let currentItem = self.playerItem else { return }
                let current = CMTimeGetSeconds(time)
                let dur = CMTimeGetSeconds(currentItem.duration)
                let validDur = dur.isFinite && dur > 0 ? dur : (self.currentSong?.duration ?? 180)
                if current.isFinite {
                    self.delegate?.nativeAudioEngineDidUpdateTime(currentTime: current, duration: validDur)
                }
            }
        }
        
        // End of track notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        print("[NativeAudioEngine] Track finished playback.")
        delegate?.nativeAudioEngineDidEnd()
    }
    
    // MARK: - Playback Controls
    public func play() {
        guard let p = player else { return }
        p.play()
    }
    
    public func pause() {
        guard let p = player else { return }
        p.pause()
    }
    
    public func seek(to seconds: TimeInterval) {
        guard let p = player else { return }
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 1000)
        p.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    public func setVolume(_ volume: Double) {
        player?.volume = Float(max(0, min(1, volume)))
    }
    
    public func cleanupPlayer() {
        if let token = timeObserverToken, let p = player {
            p.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        player?.pause()
        player = nil
        playerItem = nil
        isReady = false
    }
}
