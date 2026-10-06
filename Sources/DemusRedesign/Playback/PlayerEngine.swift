import Foundation
import Combine
import SwiftUI
@preconcurrency import AVFoundation

// MARK: - PlayerEngine
/// Real playback engine powered by Demus's WebKit Embed Architecture (WKAudioEngine),
/// providing 100% reliable background streaming, lock-screen controls, dynamic scrubbing,
/// and queue orchestration without googlevideo 403 Forbidden interruptions.
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
    public private(set) var isUsingNativeEngine: Bool = false
    public private(set) var nativePlaybackConfirmed: Bool = false
    public private(set) var lastFailureReason: String?
    
    public func playFromWebMediaSession() {
        guard !isPlaying else { return }
        self.isPlaying = true
        self.userIntentPlaying = true
        updateLockScreen()
    }
    
    public func pauseFromWebMediaSession() {
        guard isPlaying else { return }
        self.isPlaying = false
        self.userIntentPlaying = false
        updateLockScreen()
    }
    
    public var forceNativeOnly: Bool {
        get {
            if UserDefaults.standard.object(forKey: "demus_force_native_only") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "demus_force_native_only")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "demus_force_native_only")
            if newValue {
                Task { @MainActor in
                    WKAudioEngine.shared.pause()
                }
            }
        }
    }
    
    public struct DiagnosticSnapshot: Identifiable, Sendable {
        public let id = UUID()
        public let label: String
        public let timestamp: Date
        public let playerIdentifier: String
        public let itemIdentifier: String
        public let currentTime: Double
        public let rate: Float
        public let timeControlStatus: String
        public let itemStatus: String
        public let audioSessionCategory: String
        public let lastInterruption: String
        public let lastRouteChange: String
        public let lastNativeError: String
    }
    
    public private(set) var diagnosticSnapshots: [DiagnosticSnapshot] = []
    public private(set) var lastInterruptionEvent: String = "None"
    public private(set) var lastRouteChangeEvent: String = "None"
    
    public var activeEngineName: String {
        isUsingNativeEngine ? "Native AVPlayer" : "WKAudioEngine"
    }
    public var diagnosticSummary: String {
        if isUsingNativeEngine && nativePlaybackConfirmed {
            return "Native AVPlayer"
        } else if let reason = lastFailureReason {
            return reason
        } else {
            return "WKAudioEngine"
        }
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
                WKAudioEngine.shared.setVolume(v)
                NativeAudioEngine.shared.setVolume(v)
            }
        }
    }
    
    // Playback state stability & rapid-tap debounce
    private var userIntentPlaying: Bool = false
    private var lastUserToggleTime: TimeInterval = 0
    private var lastActionTime: TimeInterval = 0
    
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var willResignActiveObserver: NSObjectProtocol?
    
    public init() {
        configureAudioSession()
        setupAudioObservers()
        restoreLastSession()
        Task { @MainActor in
            WKAudioEngine.shared.delegate = self
            NativeAudioEngine.shared.delegate = self
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
    
    private func persistCurrentSession(song: Song) {
        if let data = try? JSONEncoder().encode(song) {
            UserDefaults.standard.set(data, forKey: "demus_last_song")
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
            
            self.lastInterruptionEvent = type == .began ? "Began" : "Ended"
            
            if type == .began {
                Task { @MainActor in
                    if self.isUsingNativeEngine {
                        NativeAudioEngine.shared.pause()
                    } else {
                        WKAudioEngine.shared.pause()
                    }
                }
                self.isPlaying = false
                self.updateLockScreen()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        Task { @MainActor in
                            if self.isUsingNativeEngine {
                                NativeAudioEngine.shared.play()
                            } else {
                                WKAudioEngine.shared.play()
                            }
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
            
            self.lastRouteChangeEvent = "Reason: \(reasonValue)"
            
            // If headphones unplugged or Bluetooth disconnected, pause playback
            if reason == .oldDeviceUnavailable {
                Task { @MainActor in
                    if self.isUsingNativeEngine {
                        NativeAudioEngine.shared.pause()
                    } else {
                        WKAudioEngine.shared.pause()
                    }
                }
                self.isPlaying = false
                self.updateLockScreen()
            }
        }
        
        setupBackgroundDiagnosticObserver()
        #endif
    }
    
    private func setupBackgroundDiagnosticObserver() {
        #if canImport(UIKit)
        willResignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recordSnapshot(label: "BEFORE BACKGROUND")
        }
        
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Background callbacks must LOG ONLY. Do not call play, pause, or touch player.
            self?.recordSnapshot(label: "BACKGROUND 0s")
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.recordSnapshot(label: "BACKGROUND +1s")
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self?.recordSnapshot(label: "BACKGROUND +5s")
            }
        }
        #endif
    }
    
    private func recordSnapshot(label: String) {
        Task { @MainActor in
            let native = NativeAudioEngine.shared
            let p = native.player
            let item = native.playerItem
            let playerId = String(describing: ObjectIdentifier(p))
            let itemId = item != nil ? String(describing: ObjectIdentifier(item!)) : "nil"
            let rate = p.rate
            let curTime = p.currentTime().seconds
            let tcStatus = native.timeControlStatusString
            let itemStatus = native.itemStatusString
            #if canImport(AVFAudio)
            let cat = AVAudioSession.sharedInstance().category.rawValue
            #else
            let cat = "unknown"
            #endif
            
            let snapshot = DiagnosticSnapshot(
                label: label,
                timestamp: Date(),
                playerIdentifier: playerId,
                itemIdentifier: itemId,
                currentTime: curTime,
                rate: rate,
                timeControlStatus: tcStatus,
                itemStatus: itemStatus,
                audioSessionCategory: cat,
                lastInterruption: self.lastInterruptionEvent,
                lastRouteChange: self.lastRouteChangeEvent,
                lastNativeError: self.lastFailureReason ?? "None"
            )
            
            self.diagnosticSnapshots.append(snapshot)
            if self.diagnosticSnapshots.count > 10 {
                self.diagnosticSnapshots.removeFirst()
            }
            
            print("""
            [BackgroundSnapshot \(label)]
              player: \(playerId)
              item: \(itemId)
              currentTime: \(curTime)s | rate: \(rate) | tcStatus: \(tcStatus) | itemStatus: \(itemStatus)
              audioCategory: \(cat) | lastError: \(self.lastFailureReason ?? "None")
              interruption: \(self.lastInterruptionEvent) | routeChange: \(self.lastRouteChangeEvent)
            """)
        }
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
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
            backgroundObserver = nil
        }
        if let obs = willResignActiveObserver {
            NotificationCenter.default.removeObserver(obs)
            willResignActiveObserver = nil
        }
    }
    
    // MARK: - Play Song with HD Artwork and Demus-Matched Engine
    public func play(song: Song) {
        // Upgrade artwork to crystal-clear Ultra HD
        let hdArtwork = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id)
        var upgradedSong = song
        upgradedSong.artworkURL = hdArtwork
        
        if currentSong?.id == upgradedSong.id {
            if !isPlaying {
                Task { @MainActor in
                    WKAudioEngine.shared.play()
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
        let now = Date().timeIntervalSince1970
        self.lastUserToggleTime = now
        self.lastActionTime = now
        self.errorMessage = nil
        
        // Controlled isolation: persistCurrentSession(song: upgradedSong)
        
        // Add to persistent library history
        LibraryRepository.shared.addHistory(upgradedSong)
        
        // Update Queue
        if !queue.contains(where: { $0.id == upgradedSong.id }) {
            queue.append(upgradedSong)
        }
        
        updateLockScreen()
        
        let songToPlay = upgradedSong
        let currentVideoId = upgradedSong.id
        
        #if canImport(AVFAudio)
        let diagSession = AVAudioSession.sharedInstance()
        let diagCat = diagSession.category.rawValue
        let diagOther = diagSession.isOtherAudioPlaying
        #else
        let diagCat = "unknown"
        let diagOther = false
        #endif
        #if canImport(UIKit)
        let diagState = UIApplication.shared.applicationState.rawValue
        #else
        let diagState = 0
        #endif
        print("""
        [AudioDiagnostics]
          CURRENT AUDIO ENGINE: \(isUsingNativeEngine ? "NativeAudioEngine (AVPlayer)" : "WKAudioEngine (WKWebView)")
          application state: \(diagState)
          AVAudioSession category: \(diagCat)
          AVAudioSession isOtherAudioPlaying: \(diagOther)
        """)
        
        // Play exclusively via WKAudioEngine matching Demus embed architecture
        Task { @MainActor in
            print("[PlayerEngine] Playing via WKAudioEngine for: \(songToPlay.title) (\(currentVideoId))")
            self.isUsingNativeEngine = false
            NativeAudioEngine.shared.cleanupPlayer()
            WKAudioEngine.shared.loadAndPlay(
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
        
        // Fast background lyrics pre-fetching
        let songForLyrics = upgradedSong
        Task {
            await LyricsService.shared.preloadLyrics(song: songForLyrics)
        }
    }
    
    // MARK: - Smart Queue Skipping
    /// Skips to an upcoming queue song smoothly without blowing away the existing queue.
    public func skipToQueueItem(_ song: Song) {
        guard let targetIdx = queue.firstIndex(where: { $0.id == song.id }) else {
            play(song: song)
            return
        }
        
        // Move preceding tracks to history
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
        print("[PlayerEngine] pause() CALLED! Callstack:")
        Thread.callStackSymbols.prefix(6).forEach { print("   \($0)") }
        if isPlaying {
            togglePlay()
        }
    }
    
    public func togglePlay() {
        let now = Date().timeIntervalSince1970
        guard now - lastActionTime > 0.25 else { return } // 250ms rapid-tap debounce
        lastActionTime = now
        lastUserToggleTime = now
        
        #if canImport(UIKit)
        Task { @MainActor in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        #endif
        
        if isPlaying {
            print("[PlayerEngine] togglePlay -> PAUSE triggered! Callstack:")
            Thread.callStackSymbols.prefix(6).forEach { print("   \($0)") }
            userIntentPlaying = false
            self.isPlaying = false
            self.isLoading = false
            Task { @MainActor in
                if self.isUsingNativeEngine {
                    NativeAudioEngine.shared.pause()
                } else {
                    WKAudioEngine.shared.pause()
                }
            }
        } else {
            userIntentPlaying = true
            self.isPlaying = true
            self.isLoading = true
            if currentSong != nil {
                Task { @MainActor in
                    if self.isUsingNativeEngine {
                        NativeAudioEngine.shared.play()
                    } else {
                        WKAudioEngine.shared.play()
                    }
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
        } else if isRepeat || !queue.isEmpty {
            play(song: queue[0])
        } else {
            isPlaying = false
            Task { @MainActor in
                if self.isUsingNativeEngine {
                    NativeAudioEngine.shared.pause()
                } else {
                    WKAudioEngine.shared.pause()
                }
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
    
    public func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        self.currentTime = clamped
        Task { @MainActor in
            if self.isUsingNativeEngine {
                NativeAudioEngine.shared.seek(to: clamped)
            } else {
                WKAudioEngine.shared.seek(to: clamped)
            }
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
                if self.isUsingNativeEngine {
                    NativeAudioEngine.shared.play()
                } else {
                    WKAudioEngine.shared.play()
                }
            }
        } else {
            next()
        }
    }
}

// MARK: - NativeAudioEngineDelegate
extension PlayerEngine: NativeAudioEngineDelegate {
    public func nativeAudioEngineDidReady() {
        print("[PlayerEngine] NativeAudioEngine is readyToPlay; verifying advancing playback...")
    }
    
    public func nativeAudioEngineDidConfirmPlayback() {
        self.isUsingNativeEngine = true
        self.nativePlaybackConfirmed = true
        self.lastFailureReason = nil
        Task { @MainActor in
            WKAudioEngine.shared.pause()
        }
        print("""
        ==================================================
        Playback Engine: Native AVPlayer
        ==================================================
        """)
    }
    
    public func nativeAudioEngineDidChangeState(isPlaying: Bool, isLoading: Bool) {
        guard isUsingNativeEngine else { return }
        self.isPlaying = isPlaying
        self.isLoading = isLoading
        self.userIntentPlaying = isPlaying
        updateLockScreen()
    }
    
    public func nativeAudioEngineDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval) {
        guard isUsingNativeEngine else { return }
        self.currentTime = currentTime
        if duration > 0 {
            self.duration = duration
        }
        if Int(currentTime) % 5 == 0 {
            updateLockScreen()
        }
    }
    
    public func nativeAudioEngineDidEnd() {
        guard isUsingNativeEngine else { return }
        handleSongDidEnd()
    }
    
    public func nativeAudioEngineDidFail(error: String) {
        self.nativePlaybackConfirmed = false
        self.lastFailureReason = error
        self.errorMessage = error
        
        if forceNativeOnly {
            print("[PlayerEngine] NativeAudioEngine failed: \(error), but Force Native-Only is ON. Refusing WK fallback.")
            self.isUsingNativeEngine = true
            self.isPlaying = false
            self.isLoading = false
            return
        }
        
        self.isUsingNativeEngine = false
        print("""
        ==================================================
        Playback Engine: WKAudioEngine fallback
        ==================================================
        """)
        print("[PlayerEngine] NativeAudioEngine failed: \(error). Falling back to WKAudioEngine.")
        if let current = currentSong {
            Task { @MainActor in
                NativeAudioEngine.shared.cleanupPlayer()
                WKAudioEngine.shared.loadAndPlay(videoId: current.id)
            }
        }
    }
}

// MARK: - WKAudioEngineDelegate
extension PlayerEngine: WKAudioEngineDelegate {
    public func audioEngineDidReady() {
        if !isUsingNativeEngine {
            print("""
            ==================================================
            Playback Engine: WKAudioEngine fallback
            ==================================================
            """)
        }
        print("[PlayerEngine] WKAudioEngine ready")
    }
    
    public func audioEngineDidChangeState(isPlaying: Bool, isLoading: Bool) {
        guard !isUsingNativeEngine else { return }
        let now = Date().timeIntervalSince1970
        let inGracePeriod = (now - lastUserToggleTime) < 0.6
        
        if inGracePeriod {
            // Respect user's explicit intent during grace period to prevent flickering
            if userIntentPlaying {
                self.isPlaying = true
                self.isLoading = isLoading
            } else {
                self.isPlaying = false
                self.isLoading = false
            }
        } else {
            if isLoading {
                self.isLoading = true
                if userIntentPlaying {
                    self.isPlaying = true
                }
            } else {
                self.isPlaying = isPlaying
                self.isLoading = false
                self.userIntentPlaying = isPlaying
            }
        }
        updateLockScreen()
    }
    
    public func audioEngineDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval) {
        guard !isUsingNativeEngine else { return }
        self.currentTime = currentTime
        if duration > 0 {
            self.duration = duration
        }
        if Int(currentTime) % 5 == 0 {
            updateLockScreen()
        }
    }
    
    public func audioEngineDidEnd() {
        guard !isUsingNativeEngine else { return }
        handleSongDidEnd()
    }
    
    public func audioEngineDidFail(error: String) {
        guard !isUsingNativeEngine else { return }
        self.isLoading = false
        self.errorMessage = error
        print("[PlayerEngine] WKAudioEngine error:", error)
    }
}
