import Foundation
import Combine
import SwiftUI
@preconcurrency import AVFoundation

// MARK: - PlayerEngine
/// Real AVPlayer-backed playback engine implementing Demus's HLS & direct stream playback.
@Observable
public final class PlayerEngine: @unchecked Sendable {
    public static let shared = PlayerEngine()
    
    // Playback state
    public var currentSong: Song?
    public var isPlaying: Bool = false
    public var isLoading: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 180
    public var queue: [Song] = []
    public var history: [Song] = []
    public var isShuffle: Bool = false
    public var isRepeat: Bool = false
    public var errorMessage: String?
    
    // Core AVPlayer
    private var avPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var itemEndObserver: NSObjectProtocol?
    
    public init() {
        configureAudioSession()
    }
    
    deinit {
        cleanupPlayer()
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        #if canImport(AVFAudio)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession:", error)
        }
        #endif
    }
    
    // MARK: - Play Song with Real Stream Resolution
    public func play(song: Song) {
        // If already playing this song, just toggle play
        if currentSong?.id == song.id, let player = avPlayer {
            if !isPlaying {
                player.play()
                isPlaying = true
            }
            return
        }
        
        self.currentSong = song
        self.currentTime = 0
        self.duration = song.duration > 0 ? song.duration : 180
        self.isPlaying = false
        self.isLoading = true
        self.errorMessage = nil
        
        // Add to history
        LibraryRepository.shared.addHistory(song)
        
        // Add to queue if not present
        if !queue.contains(where: { $0.id == song.id }) {
            queue.append(song)
        }
        
        Task { @MainActor in
            do {
                let resolved = try await StreamResolutionService.shared.resolveStream(for: song)
                self.loadAndPlay(streamURL: resolved.url, expectedDuration: resolved.duration)
            } catch {
                self.isLoading = false
                self.errorMessage = "Unable to resolve stream: \(error.localizedDescription)"
                print("Stream resolution error:", error)
            }
        }
    }
    
    // MARK: - Load Stream into AVPlayer
    private func loadAndPlay(streamURL: URL, expectedDuration: TimeInterval) {
        cleanupPlayer()
        
        let playerItem = AVPlayerItem(url: streamURL)
        let player = AVPlayer(playerItem: playerItem)
        self.avPlayer = player
        
        // Observe status (ready to play)
        itemStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.isLoading = false
                    self.isPlaying = true
                    player.play()
                    
                    let itemDuration = item.duration.seconds
                    if !itemDuration.isNaN && itemDuration > 0 {
                        self.duration = itemDuration
                    } else if expectedDuration > 0 {
                        self.duration = expectedDuration
                    }
                } else if item.status == .failed {
                    self.isLoading = false
                    self.isPlaying = false
                    self.errorMessage = item.error?.localizedDescription ?? "Playback failed"
                }
            }
        }
        
        // Observe time progression
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.isPlaying else { return }
            let secs = time.seconds
            if !secs.isNaN && secs >= 0 {
                self.currentTime = secs
            }
        }
        
        // Observe play to end
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleSongDidEnd()
        }
    }
    
    // MARK: - Playback Controls
    public func togglePlay() {
        guard let player = avPlayer else {
            if let song = currentSong {
                play(song: song)
            } else if let first = queue.first {
                play(song: first)
            }
            return
        }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    public func next() {
        guard let current = currentSong, let idx = queue.firstIndex(where: { $0.id == current.id }) else {
            if let first = queue.first { play(song: first) }
            return
        }
        
        history.append(current)
        
        if isShuffle {
            let candidates = queue.filter { $0.id != current.id }
            if let randomSong = candidates.randomElement() {
                play(song: randomSong)
                return
            }
        }
        
        if idx + 1 < queue.count {
            play(song: queue[idx + 1])
        } else if isRepeat || !queue.isEmpty {
            play(song: queue[0])
        } else {
            isPlaying = false
            cleanupPlayer()
        }
    }
    
    public func prev() {
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        guard let current = currentSong, let idx = queue.firstIndex(where: { $0.id == current.id }) else { return }
        if idx > 0 {
            play(song: queue[idx - 1])
        } else if let last = queue.last {
            play(song: last)
        }
    }
    
    public func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        self.currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        avPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    public func toggleFavorite(for songId: String) {
        if let idx = queue.firstIndex(where: { $0.id == songId }) {
            queue[idx].isFavorite.toggle()
            LibraryRepository.shared.toggleFavorite(for: queue[idx])
            if currentSong?.id == songId {
                currentSong?.isFavorite = queue[idx].isFavorite
            }
        }
    }
    
    private func handleSongDidEnd() {
        if isRepeat {
            seek(to: 0)
            avPlayer?.play()
        } else {
            next()
        }
    }
    
    private func cleanupPlayer() {
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let endObs = itemEndObserver {
            NotificationCenter.default.removeObserver(endObs)
            itemEndObserver = nil
        }
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        
        avPlayer?.pause()
        avPlayer = nil
    }
}
