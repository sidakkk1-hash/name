import Foundation
import AVFoundation
import Combine
import SwiftUI
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

// MARK: - NativePlayerDiagnostics
public struct NativePlayerDiagnostics: Sendable {
    public var itemStatus: String = "idle"
    public var itemError: String = "None"
    public var timeControlStatus: String = "paused"
    public var waitingReason: String = "None"
    public var rate: Float = 0.0
    public var currentTime: Double = 0.0
    public var duration: Double = 0.0
    public var playbackStalled: Bool = false
    public var appState: String = "active"
    public var lastStreamHost: String = "None"
}

// MARK: - NativeAudioEngine
/// The sole playback engine for Demus: 100% native AVPlayer audio playback.
/// Resolves stream URLs via WKStreamExtractor, then hands them to AVPlayerItem.
/// Plays continuously in background & lock screen without WebKit audio hacks.
@Observable
@MainActor
public final class NativeAudioEngine: NSObject, @unchecked Sendable {
    public static let shared = NativeAudioEngine()
    
    public weak var delegate: NativeAudioEngineDelegate?
    
    public private(set) var player: AVPlayer
    public private(set) var playerItem: AVPlayerItem?
    
    public private(set) var isReady: Bool = false
    public private(set) var isPlaying: Bool = false
    public private(set) var isLoading: Bool = false
    public private(set) var lastFailureReason: String?
    public private(set) var currentSong: Song?
    
    public var diagnostics = NativePlayerDiagnostics()
    
    private var timeObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var waitingReasonObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var stalledObserver: (any NSObjectProtocol)?
    private var endObserver: (any NSObjectProtocol)?
    private var appStateObservers: [any NSObjectProtocol] = []
    
    override public init() {
        let p = AVPlayer()
        p.automaticallyWaitsToMinimizeStalling = true
        self.player = p
        super.init()
        
        setupAudioSession()
        setupPlayerObservations()
        setupAppStateObservations()
    }
    
    // MARK: - Audio Session
    private func setupAudioSession() {
        #if canImport(AVFAudio)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
            try session.setActive(true)
            print("[NativeAudioEngine] AVAudioSession configured: .playback, active=true")
        } catch {
            print("[NativeAudioEngine] AVAudioSession setup error:", error)
        }
        #endif
    }
    
    // MARK: - Load and Play
    public func loadAndPlay(song: Song) async -> Bool {
        self.currentSong = song
        self.isReady = false
        self.isLoading = true
        self.lastFailureReason = nil
        self.diagnostics.playbackStalled = false
        self.diagnostics.itemError = "None"
        self.diagnostics.itemStatus = "extracting"
        
        let videoId = song.id
        print("[NativeAudioEngine] Extracting stream for videoId: \(videoId)")
        
        // 1. Resolve stream via WKStreamExtractor
        let streamURL: URL
        do {
            streamURL = try await WKStreamExtractor.shared.extractStreamURL(for: videoId)
        } catch {
            let errMsg = error.localizedDescription
            self.lastFailureReason = errMsg
            self.diagnostics.itemStatus = "extraction_failed"
            self.diagnostics.itemError = errMsg
            self.isLoading = false
            self.isPlaying = false
            print("[NativeAudioEngine] Stream extraction failed: \(errMsg)")
            delegate?.nativeAudioEngineDidFail(error: errMsg)
            return false
        }
        
        guard let host = streamURL.host else {
            let errMsg = "Extracted URL missing host"
            self.lastFailureReason = errMsg
            self.diagnostics.itemStatus = "invalid_url"
            self.diagnostics.itemError = errMsg
            self.isLoading = false
            delegate?.nativeAudioEngineDidFail(error: errMsg)
            return false
        }
        
        self.diagnostics.lastStreamHost = host
        print("[NativeAudioEngine] Loading AVPlayerItem with host: \(host)")
        
        // 2. Setup native AVPlayerItem
        cleanupCurrentItem()
        
        let item = AVPlayerItem(url: streamURL)
        item.preferredForwardBufferDuration = 15.0
        self.playerItem = item
        setupItemObservations(for: item)
        
        player.replaceCurrentItem(with: item)
        player.play()
        
        return true
    }
    
    // MARK: - Playback Controls
    public func play() {
        setupAudioSession()
        player.play()
    }
    
    public func pause() {
        player.pause()
    }
    
    public func togglePlay() {
        if player.timeControlStatus == .playing {
            pause()
        } else {
            play()
        }
    }
    
    public func seek(to seconds: TimeInterval) {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    public func setVolume(_ volume: Double) {
        player.volume = Float(volume)
    }
    
    public var timeControlStatusString: String {
        diagnostics.timeControlStatus
    }
    
    public var itemStatusString: String {
        diagnostics.itemStatus
    }
    
    public func cleanupPlayer() {
        cleanupCurrentItem()
        player.replaceCurrentItem(with: nil)
        self.isReady = false
        self.isPlaying = false
        self.isLoading = false
        self.diagnostics.itemStatus = "idle"
    }
    
    // MARK: - Item Observations
    private func setupItemObservations(for item: AVPlayerItem) {
        // Observe AVPlayerItem.status
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] it, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch it.status {
                case .readyToPlay:
                    self.isReady = true
                    self.diagnostics.itemStatus = "readyToPlay"
                    self.diagnostics.itemError = "None"
                    let dur = it.duration.seconds
                    if dur.isFinite && dur > 0 {
                        self.diagnostics.duration = dur
                    }
                    print("[NativeAudioEngine] AVPlayerItem is readyToPlay")
                    self.delegate?.nativeAudioEngineDidReady()
                    
                case .failed:
                    self.isReady = false
                    self.isLoading = false
                    self.isPlaying = false
                    let errStr = it.error?.localizedDescription ?? "AVPlayerItem failed"
                    self.lastFailureReason = errStr
                    self.diagnostics.itemStatus = "failed"
                    self.diagnostics.itemError = errStr
                    print("[NativeAudioEngine] AVPlayerItem failed: \(errStr)")
                    self.delegate?.nativeAudioEngineDidFail(error: errStr)
                    
                case .unknown:
                    self.diagnostics.itemStatus = "unknown"
                    
                @unknown default:
                    break
                }
            }
        }
        
        // Observe playback stalled notification
        stalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.diagnostics.playbackStalled = true
                print("[NativeAudioEngine] Playback stalled notification received")
            }
        }
        
        // Observe item did play to end
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("[NativeAudioEngine] Song finished playing")
                self.delegate?.nativeAudioEngineDidEnd()
            }
        }
    }
    
    // MARK: - Player Observations
    private func setupPlayerObservations() {
        // 1. timeControlStatus
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] p, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch p.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.isLoading = false
                    self.diagnostics.timeControlStatus = "playing"
                    self.delegate?.nativeAudioEngineDidChangeState(isPlaying: true, isLoading: false)
                case .paused:
                    self.isPlaying = false
                    self.isLoading = false
                    self.diagnostics.timeControlStatus = "paused"
                    self.delegate?.nativeAudioEngineDidChangeState(isPlaying: false, isLoading: false)
                case .waitingToPlayAtSpecifiedRate:
                    self.isPlaying = false
                    self.isLoading = true
                    self.diagnostics.timeControlStatus = "waitingToPlay"
                    self.delegate?.nativeAudioEngineDidChangeState(isPlaying: false, isLoading: true)
                @unknown default:
                    break
                }
            }
        }
        
        // 2. reasonForWaitingToPlay
        waitingReasonObservation = player.observe(\.reasonForWaitingToPlay, options: [.initial, .new]) { [weak self] p, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let reason = p.reasonForWaitingToPlay {
                    self.diagnostics.waitingReason = reason.rawValue
                } else {
                    self.diagnostics.waitingReason = "None"
                }
            }
        }
        
        // 3. rate
        rateObservation = player.observe(\.rate, options: [.initial, .new]) { [weak self] p, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.diagnostics.rate = p.rate
            }
        }
        
        // 4. Periodic time updates (every 250ms)
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let cur = time.seconds
                guard cur.isFinite else { return }
                self.diagnostics.currentTime = cur
                
                var dur: Double = 0
                if let it = self.playerItem {
                    let d = it.duration.seconds
                    if d.isFinite && d > 0 {
                        dur = d
                        self.diagnostics.duration = d
                    }
                }
                
                self.delegate?.nativeAudioEngineDidUpdateTime(currentTime: cur, duration: dur)
            }
        }
    }
    
    // MARK: - App State Observations
    private func setupAppStateObservations() {
        #if canImport(UIKit)
        let activeObs = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.diagnostics.appState = "active"
            }
        }
        
        let bgObs = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.diagnostics.appState = "background"
            }
        }
        
        appStateObservers = [activeObs, bgObs]
        #endif
    }
    
    private func cleanupCurrentItem() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let s = stalledObserver {
            NotificationCenter.default.removeObserver(s)
            stalledObserver = nil
        }
        if let e = endObserver {
            NotificationCenter.default.removeObserver(e)
            endObserver = nil
        }
        playerItem = nil
    }
    
    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }
}
