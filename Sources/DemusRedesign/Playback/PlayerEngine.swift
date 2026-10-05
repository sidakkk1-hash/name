import Foundation
import Combine
import SwiftUI
@preconcurrency import AVFoundation

// MARK: - PlayerEngine
/// Real AVPlayer-backed playback engine implementing Demus's HLS & direct stream playback,
/// background audio, Lock Screen controls, and interruption management.
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
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    
    public init() {
        configureAudioSession()
        setupAudioObservers()
        NowPlayingManager.shared.setupRemoteCommands(player: self)
    }
    
    deinit {
        cleanupPlayer()
        removeAudioObservers()
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        #if canImport(AVFAudio)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession:", error)
        }
        #endif
    }
    
    // MARK: - Audio Interruption & Route Change Observers
    private func setupAudioObservers() {
        #if canImport(AVFAudio)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            if type == .began {
                self.avPlayer?.pause()
                self.isPlaying = false
                self.updateLockScreen()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.avPlayer?.play()
                        self.isPlaying = true
                        self.updateLockScreen()
                    }
                }
            }
        }
        
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            
            // If headphones unplugged or Bluetooth disconnected, pause playback
            if reason == .oldDeviceUnavailable {
                self.avPlayer?.pause()
                self.isPlaying = false
                self.updateLockScreen()
            }
        }
        #endif
    }
    
    private func removeAudioObservers() {
        if let obs = interruptionObserver {
            NotificationCenter.default.removeObserver(obs)
            interruptionObserver = nil
        }
        if let obs = routeChangeObserver {
            NotificationCenter.default.removeObserver(obs)
            routeChangeObserver = nil
        }
    }
    
    // MARK: - Play Song with Real Stream Resolution
    public func play(song: Song) {
        if currentSong?.id == song.id, let player = avPlayer {
            if !isPlaying {
                player.play()
                isPlaying = true
                updateLockScreen()
            }
            return
        }
        
        self.currentSong = song
        self.currentTime = 0
        self.duration = song.duration > 0 ? song.duration : 180
        self.isPlaying = false
        self.isLoading = true
        self.errorMessage = nil
        
        // Add to persistent library history
        LibraryRepository.shared.addHistory(song)
        
        // Update Queue
        if !queue.contains(where: { $0.id == song.id }) {
            queue.append(song)
        }
        
        updateLockScreen()
        
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
    
    // MARK: - Load Stream into AVPlayer with Headers
    private func loadAndPlay(streamURL: URL, expectedDuration: TimeInterval) {
        cleanupPlayer()
        
        // Configure AVURLAsset with Demus-matched User-Agent
        let headers: [String: String] = [
            "User-Agent": "com.google.ios.youtube/20.25.4 (iPhone17,1; U; CPU iOS 18_5 like Mac OS X)"
        ]
        let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
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
                    self.updateLockScreen()
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
                // Periodic lock screen progress update every ~5s
                if Int(secs) % 5 == 0 {
                    self.updateLockScreen()
                }
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
        updateLockScreen()
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
            updateLockScreen()
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
        updateLockScreen()
    }
    
    public func toggleFavorite(for songId: String) {
        if let idx = queue.firstIndex(where: { $0.id == songId }) {
            queue[idx].isFavorite.toggle()
            LibraryRepository.shared.toggleFavorite(for: queue[idx])
            if currentSong?.id == songId {
                currentSong?.isFavorite = queue[idx].isFavorite
            }
        } else if let song = currentSong, song.id == songId {
            currentSong?.isFavorite.toggle()
            if let updated = currentSong {
                LibraryRepository.shared.toggleFavorite(for: updated)
            }
        }
    }
    
    // MARK: - Queue Management
    public func playAll(songs: [Song], startingAt index: Int = 0, shuffle: Bool = false) {
        guard !songs.isEmpty else { return }
        if shuffle {
            self.isShuffle = true
            let shuffled = songs.shuffled()
            self.queue = shuffled
            if let first = shuffled.first {
                play(song: first)
            }
        } else {
            self.isShuffle = false
            self.queue = songs
            let validIndex = (index >= 0 && index < songs.count) ? index : 0
            play(song: songs[validIndex])
        }
    }
    
    public func addToQueue(_ song: Song) {
        if !queue.contains(where: { $0.id == song.id }) {
            queue.append(song)
        }
    }
    
    public func playNext(_ song: Song) {
        queue.removeAll(where: { $0.id == song.id })
        if let current = currentSong, let idx = queue.firstIndex(where: { $0.id == current.id }) {
            queue.insert(song, at: idx + 1)
        } else {
            queue.insert(song, at: 0)
        }
    }
    
    public func removeFromQueue(id: String) {
        queue.removeAll(where: { $0.id == id })
    }
    
    public func removeFromQueue(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
    }
    
    public func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
    }
    
    public func clearQueue() {
        if let current = currentSong {
            queue = [current]
        } else {
            queue.removeAll()
        }
    }
    
    private func updateLockScreen() {
        NowPlayingManager.shared.updateNowPlaying(
            song: currentSong,
            currentTime: currentTime,
            duration: duration,
            isPlaying: isPlaying
        )
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
