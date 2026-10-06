import Foundation
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - NativeAudioEngineDelegate
public protocol NativeAudioEngineDelegate: AnyObject, Sendable {
    func nativeAudioEngineDidReady()
    func nativeAudioEngineDidConfirmPlayback()
    func nativeAudioEngineDidChangeState(isPlaying: Bool, isLoading: Bool)
    func nativeAudioEngineDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval)
    func nativeAudioEngineDidEnd()
    func nativeAudioEngineDidFail(error: String)
}

// MARK: - NativeAudioEngine
/// App-lifetime Native AVPlayer audio engine.
/// Created once, runs alongside WKAudioEngine fallback, verifying actual advancing playback
/// before declaring Native AVPlayer active.
@MainActor
public final class NativeAudioEngine: NSObject, @unchecked Sendable {
    public static let shared = NativeAudioEngine()
    
    public weak var delegate: NativeAudioEngineDelegate?
    
    public private(set) var player: AVPlayer
    public private(set) var playerItem: AVPlayerItem?
    
    public private(set) var isReady: Bool = false
    public private(set) var nativePlaybackConfirmed: Bool = false
    public private(set) var lastFailureReason: String?
    public private(set) var currentSong: Song?
    
    private var timeObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var verificationTask: Task<Void, Never>?
    
    override public init() {
        let p = AVPlayer()
        p.automaticallyWaitsToMinimizeStalling = true
        self.player = p
        super.init()
    }
    
    // MARK: - Load and Play
    public func loadAndPlay(song: Song) async -> Bool {
        self.currentSong = song
        self.isReady = false
        self.nativePlaybackConfirmed = false
        self.lastFailureReason = nil
        
        let videoId = song.id
        print("[NativeAudioEngine] Resolving stream for videoId: \(videoId)")
        
        let stream: StreamResolutionService.ResolvedStream
        do {
            stream = try await StreamResolutionService.shared.resolveStream(for: song)
        } catch let err as StreamResolutionError {
            let reason = err.errorDescription ?? "Native failure: StreamResolutionFailed"
            self.lastFailureReason = reason
            print("[NativeAudioEngine] Stream resolution failed: \(reason)")
            delegate?.nativeAudioEngineDidFail(error: reason)
            return false
        } catch {
            let reason = "Native failure: StreamResolutionFailed"
            self.lastFailureReason = reason
            print("[NativeAudioEngine] Stream resolution failed: \(error)")
            delegate?.nativeAudioEngineDidFail(error: reason)
            return false
        }
        
        // Build AVURLAsset with verified headers
        let asset: AVURLAsset
        if let headers = stream.headers, !headers.isEmpty {
            asset = AVURLAsset(url: stream.url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        } else {
            asset = AVURLAsset(url: stream.url)
        }
        
        cleanupCurrentItem()
        
        let item = AVPlayerItem(asset: asset)
        self.playerItem = item
        
        setupObservers(for: item)
        player.replaceCurrentItem(with: item)
        
        return true
    }
    
    // MARK: - Observers
    private func setupObservers(for item: AVPlayerItem) {
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
                    self.onItemReadyToPlay()
                    
                case .failed:
                    self.isReady = false
                    self.nativePlaybackConfirmed = false
                    let reason = "Native failure: AVPlayerItemFailed"
                    self.lastFailureReason = reason
                    print("[NativeAudioEngine] Item failed: \(observedItem.error?.localizedDescription ?? "unknown")")
                    self.delegate?.nativeAudioEngineDidFail(error: reason)
                    
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
                self.delegate?.nativeAudioEngineDidChangeState(isPlaying: isPlaying, isLoading: isLoading)
            }
        }
        
        // Periodic Time Observer (every 0.5s)
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
    
    private func onItemReadyToPlay() {
        guard let item = playerItem, item.status == .readyToPlay else { return }
        self.isReady = true
        delegate?.nativeAudioEngineDidReady()
        
        print("""
        [NativeAudioEngine] readyToPlay reached!
        [NativeAudioEngine] player.timeControlStatus: \(player.timeControlStatus.rawValue)
        [NativeAudioEngine] player.reasonForWaitingToPlay: \(String(describing: player.reasonForWaitingToPlay))
        """)
        
        player.play()
        
        // Begin strict playback verification
        verificationTask?.cancel()
        verificationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.verifyPlaybackAdvancing()
        }
    }
    
    // MARK: - Native Playback Verification (2-second advance check)
    private func verifyPlaybackAdvancing() async {
        // 1. Wait for player to enter playing state (up to 3.0 seconds)
        let startWait = Date()
        while player.timeControlStatus != .playing && Date().timeIntervalSince(startWait) < 3.0 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
        }
        
        guard let currentItem = playerItem, currentItem.status == .readyToPlay else {
            let reason = "Native failure: AVPlayerItemFailed"
            self.lastFailureReason = reason
            self.nativePlaybackConfirmed = false
            print("[NativeAudioEngine] Verification failed: \(reason)")
            delegate?.nativeAudioEngineDidFail(error: reason)
            return
        }
        
        if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            let reason = "Native failure: WaitingToMinimizeStalls"
            self.lastFailureReason = reason
            self.nativePlaybackConfirmed = false
            print("[NativeAudioEngine] Verification failed: \(reason)")
            delegate?.nativeAudioEngineDidFail(error: reason)
            return
        }
        
        guard player.timeControlStatus == .playing && player.rate > 0 else {
            let reason = "Native failure: ReadyButNotPlaying"
            self.lastFailureReason = reason
            self.nativePlaybackConfirmed = false
            print("[NativeAudioEngine] Verification failed: \(reason)")
            delegate?.nativeAudioEngineDidFail(error: reason)
            return
        }
        
        // 2. Measure currentTime advance over 2 seconds
        let time1 = player.currentTime().seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if Task.isCancelled { return }
        let time2 = player.currentTime().seconds
        
        print("""
        [NativeAudioEngine] Advancing Verification:
          time1: \(time1)
          time2: \(time2)
          advance: \(time2 - time1)
          rate: \(player.rate)
          timeControlStatus: \(player.timeControlStatus.rawValue)
        """)
        
        if time2 > time1 && (time2 - time1) >= 1.0 {
            // Strict verification succeeded:
            // - stream URL resolved
            // - AVPlayerItem.status == .readyToPlay
            // - AVPlayer.timeControlStatus == .playing
            // - player.rate > 0
            // - currentTime advances for at least 2 seconds
            self.nativePlaybackConfirmed = true
            self.lastFailureReason = nil
            print("[NativeAudioEngine] Strict verification SUCCESSFUL! Confirmed Native AVPlayer active.")
            delegate?.nativeAudioEngineDidConfirmPlayback()
            delegate?.nativeAudioEngineDidChangeState(isPlaying: true, isLoading: false)
        } else {
            let reason = "Native failure: CurrentTimeNotAdvancing"
            self.lastFailureReason = reason
            self.nativePlaybackConfirmed = false
            print("[NativeAudioEngine] Verification failed: \(reason)")
            delegate?.nativeAudioEngineDidFail(error: reason)
        }
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        print("[NativeAudioEngine] Track finished playback.")
        delegate?.nativeAudioEngineDidEnd()
    }
    
    // MARK: - Playback Controls
    public func play() {
        player.play()
    }
    
    public func pause() {
        print("[NativeAudioEngine] pause() CALLED! Callstack:")
        Thread.callStackSymbols.prefix(6).forEach { print("   \($0)") }
        player.pause()
    }
    
    public func seek(to seconds: TimeInterval) {
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    public func setVolume(_ volume: Double) {
        player.volume = Float(max(0, min(1, volume)))
    }
    
    public func cleanupCurrentItem() {
        print("[NativeAudioEngine] cleanupCurrentItem() / cleanupPlayer() CALLED! Callstack:")
        Thread.callStackSymbols.prefix(6).forEach { print("   \($0)") }
        verificationTask?.cancel()
        verificationTask = nil
        
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        player.pause()
        player.replaceCurrentItem(with: nil)
        playerItem = nil
        isReady = false
        nativePlaybackConfirmed = false
    }
    
    public func cleanupPlayer() {
        cleanupCurrentItem()
    }
    
    // MARK: - Diagnostics Helpers
    public var itemStatusString: String {
        guard let item = playerItem else { return "none" }
        switch item.status {
        case .readyToPlay: return "readyToPlay"
        case .failed: return "failed"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }
    
    public var timeControlStatusString: String {
        switch player.timeControlStatus {
        case .playing: return "playing"
        case .paused: return "paused"
        case .waitingToPlayAtSpecifiedRate: return "waiting"
        @unknown default: return "unknown"
        }
    }
}
