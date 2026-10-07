import Foundation
import Combine
import SwiftUI
#if canImport(AVFAudio)
import AVFAudio
#endif

// MARK: - PlayerEngine
/// Primary music player orchestrator for Demus.
/// Coordinates queue, history, repeat/shuffle, and lock-screen/Control Center integration.
/// Playback is executed natively via the authentic Demus-style WebKit Embed Engine (WKEmbedAudioEngine).
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
    public var isAutoplayEnabled: Bool = true
    public var isCrossfadeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "demus_crossfade_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "demus_crossfade_enabled") }
    }
    public var crossfadeDuration: Double {
        get {
            let val = UserDefaults.standard.double(forKey: "demus_crossfade_duration")
            return val == 0 ? 6.0 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "demus_crossfade_duration") }
    }
    private var isCrossfading: Bool = false
    public var errorMessage: String?
    public let isUsingNativeEngine: Bool = false
    
    public var activeEngineName: String {
        "WebKit EmbedPlayer"
    }
    
    public var audioSessionCategoryString: String {
        #if canImport(AVFAudio)
        return AVAudioSession.sharedInstance().category.rawValue
        #else
        return "unknown"
        #endif
    }
    
    public var appStateString: String {
        #if canImport(UIKit)
        switch UIApplication.shared.applicationState {
        case .active: return "active (foreground)"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
        #else
        return "unknown"
        #endif
    }
    
    public var volume: Double = 1.0 {
        didSet {
            let v = volume
            Task { @MainActor in
                WKEmbedAudioEngine.shared.setVolume(v)
            }
        }
    }
    
    // Playback state stability & rapid-tap debounce
    private var userIntentPlaying: Bool = false
    private var lastUserToggleTime: TimeInterval = 0
    private var lastActionTime: TimeInterval = 0
    
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    
    public init() {
        configureAudioSession()
        setupAudioObservers()
        restoreLastSession()
        Task { @MainActor in
            WKEmbedAudioEngine.shared.delegate = self
        }
        NowPlayingManager.shared.setupRemoteCommands(player: self)
    }
    
    deinit {
        removeAudioObservers()
    }
    
    private func restoreLastSession() {
        if let data = UserDefaults.standard.data(forKey: "demus_last_song"),
           let song = try? JSONDecoder().decode(Song.self, from: data) {
            self.currentSong = song
            self.duration = song.duration > 0 ? song.duration : 180
            self.queue = [song]
        }
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        #if canImport(AVFAudio)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
            try session.setActive(true)
            print("[PlayerEngine] AVAudioSession configured: .playback, active=true")
        } catch {
            print("[PlayerEngine] Failed to configure AVAudioSession:", error)
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
                Task { @MainActor in
                    WKEmbedAudioEngine.shared.pause()
                }
                self.isPlaying = false
                self.updateLockScreen()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        Task { @MainActor in
                            WKEmbedAudioEngine.shared.play()
                        }
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
                Task { @MainActor in
                    WKEmbedAudioEngine.shared.pause()
                }
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
    
    // MARK: - Play Song via WKEmbedAudioEngine
    public func play(song: Song) {
        // Upgrade artwork to HD
        let hdArtwork = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id)
        var upgradedSong = song
        upgradedSong.artworkURL = hdArtwork
        
        if currentSong?.id == upgradedSong.id {
            if !isPlaying {
                Task { @MainActor in
                    WKEmbedAudioEngine.shared.play()
                }
                isPlaying = true
                updateLockScreen()
            }
            return
        }
        
        self.currentSong = upgradedSong
        self.currentTime = 0
        self.duration = upgradedSong.duration > 0 ? upgradedSong.duration : 180
        self.isPlaying = false
        self.isLoading = true
        self.userIntentPlaying = true
        self.isCrossfading = false
        MusicHapticsManager.shared.triggerTrackChangeHaptic()
        let now = Date().timeIntervalSince1970
        self.lastUserToggleTime = now
        self.lastActionTime = now
        self.errorMessage = nil
        
        // Add to persistent library history
        LibraryRepository.shared.addHistory(upgradedSong)
        
        // Update Queue
        if !queue.contains(where: { $0.id == upgradedSong.id }) {
            queue.append(upgradedSong)
        }
        
        updateLockScreen()
        
        let songToPlay = upgradedSong
        let currentVideoId = upgradedSong.id
        
        print("""
        [PlayerEngine] Playing via WKEmbedAudioEngine:
          Title: \(songToPlay.title)
          VideoID: \(currentVideoId)
          Engine: WebKit EmbedPlayer
        """)
        
        Task { @MainActor in
            WKEmbedAudioEngine.shared.loadAndPlay(
                videoId: currentVideoId,
                title: songToPlay.title,
                artist: songToPlay.artistName,
                album: songToPlay.albumName ?? "",
                artworkUrl: songToPlay.artworkURL?.absoluteString ?? "",
                duration: upgradedSong.duration
            )
        }
        
        // Auto-fetch algorithmic Up Next songs like YouTube Music
        fetchRadioQueue(for: currentVideoId)
        
        // Background lyrics pre-fetching
        let songForLyrics = upgradedSong
        Task {
            await LyricsService.shared.preloadLyrics(song: songForLyrics)
        }
    }
    
    // MARK: - Smart Queue Skipping
    public func skipToQueueItem(_ song: Song) {
        guard let targetIdx = queue.firstIndex(where: { $0.id == song.id }) else {
            play(song: song)
            return
        }
        
        if targetIdx > 0 {
            let preceding = Array(queue.prefix(targetIdx))
            history.append(contentsOf: preceding)
            queue.removeFirst(targetIdx)
        }
        
        guard let target = queue.first else { return }
        play(song: target)
    }
    
    private func fetchRadioQueue(for videoId: String) {
        Task {
            let radioSongs = await RadioService.shared.fetchUpNext(videoId: videoId)
            self.appendRadioSongs(radioSongs)
        }
    }
    
    private func appendRadioSongs(_ songs: [Song]) {
        for song in songs {
            if !queue.contains(where: { $0.id == song.id }) {
                queue.append(song)
            }
        }
    }
    
    // MARK: - Playback Controls
    public func play() {
        if !isPlaying {
            togglePlay()
        }
    }
    
    public func pause() {
        if isPlaying {
            togglePlay()
        }
    }
    
    public func togglePlay() {
        let now = Date().timeIntervalSince1970
        guard now - lastActionTime > 0.25 else { return } // 250ms debounce
        lastActionTime = now
        lastUserToggleTime = now
        
        #if canImport(UIKit)
        Task { @MainActor in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        #endif
        
        if isPlaying {
            userIntentPlaying = false
            self.isPlaying = false
            self.isLoading = false
            Task { @MainActor in
                WKEmbedAudioEngine.shared.pause()
            }
        } else {
            userIntentPlaying = true
            self.isPlaying = true
            self.isLoading = true
            if currentSong != nil {
                Task { @MainActor in
                    WKEmbedAudioEngine.shared.play()
                }
            } else if let first = queue.first {
                play(song: first)
            }
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
        } else if isAutoplayEnabled, let last = currentSong {
            Task {
                let similar = await RadioService.shared.fetchUpNext(videoId: last.id)
                if let nextSong = similar.first {
                    await MainActor.run {
                        self.appendRadioSongs(similar)
                        self.play(song: nextSong)
                    }
                } else if self.isRepeat || !self.queue.isEmpty {
                    await MainActor.run {
                        self.play(song: self.queue[0])
                    }
                }
            }
        } else if isRepeat || !queue.isEmpty {
            play(song: queue[0])
        } else {
            isPlaying = false
            Task { @MainActor in
                WKEmbedAudioEngine.shared.pause()
            }
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
    
    public func previous() {
        prev()
    }
    
    public func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        self.currentTime = clamped
        Task { @MainActor in
            WKEmbedAudioEngine.shared.seek(to: clamped)
        }
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
            Task { @MainActor in
                WKEmbedAudioEngine.shared.play()
            }
        } else {
            next()
        }
    }
    
    private func startCrossfade(remaining: Double) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let steps = 8
            let stepDelay = max(0.1, remaining / Double(steps))
            for i in 1...steps {
                guard self.isCrossfading, self.isPlaying else { break }
                let fraction = Double(steps - i) / Double(steps)
                WKEmbedAudioEngine.shared.setVolume(self.volume * fraction)
                try? await Task.sleep(nanoseconds: UInt64(stepDelay * 1_000_000_000))
            }
            guard self.isCrossfading else { return }
            self.next()
            try? await Task.sleep(nanoseconds: 500_000_000)
            WKEmbedAudioEngine.shared.setVolume(self.volume)
            self.isCrossfading = false
        }
    }
}

// MARK: - WKEmbedAudioEngineDelegate
extension PlayerEngine: WKEmbedAudioEngineDelegate {
    public func embedAudioEngineDidReady() {
        print("[PlayerEngine] WKEmbedAudioEngine is ready")
    }
    
    public func embedAudioEngineDidChangeState(isPlaying: Bool, isLoading: Bool) {
        self.isPlaying = isPlaying
        self.isLoading = isLoading
        self.userIntentPlaying = isPlaying
        MusicHapticsManager.shared.handlePlaybackStateChange(isPlaying: isPlaying)
        updateLockScreen()
    }
    
    public func embedAudioEngineDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval) {
        self.currentTime = currentTime
        if duration > 0 {
            self.duration = duration
        }
        
        // Dynamic Crossfade Transition
        if isCrossfadeEnabled && duration > (crossfadeDuration + 5.0) && !isCrossfading {
            let remaining = duration - currentTime
            if remaining <= crossfadeDuration && remaining > 1.0 {
                isCrossfading = true
                startCrossfade(remaining: remaining)
            }
        }
        
        if Int(currentTime) % 5 == 0 {
            updateLockScreen()
        }
    }

    public func embedAudioEngineDidEnd() {
        isCrossfading = false
        handleSongDidEnd()
    }
    
    public func embedAudioEngineDidFail(error: String) {
        self.isPlaying = false
        self.isLoading = false
        self.isCrossfading = false
        self.errorMessage = error
        MusicHapticsManager.shared.handlePlaybackStateChange(isPlaying: false)
        updateLockScreen()
        print("[PlayerEngine] WKEmbedAudioEngine error: \(error)")
    }
    
    public func embedAudioEngineDidRequestNext() {
        next()
    }
    
    public func embedAudioEngineDidRequestPrev() {
        prev()
    }
}
