import Foundation
import Combine
import SwiftUI
@preconcurrency import AVFoundation

// MARK: - PlayerEngine
/// Production-grade native AVFoundation playback engine powering background audio,
/// Lock Screen controls, Dynamic Island, Control Center, and seamless queue orchestration.
@Observable
public final class PlayerEngine: @unchecked Sendable {
    public static let shared = PlayerEngine()
    
    // Playback state (authoritative source of truth)
    public var currentSong: Song?
    public var playbackState: PlaybackState = .idle
    public var isPlaying: Bool = false
    public var isLoading: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 180
    public var queue: [Song] = []
    public var history: [Song] = []
    public var isShuffle: Bool = false
    public var isRepeat: Bool = false
    public var errorMessage: String?
    public var volume: Double = 1.0 {
        didSet {
            avPlayer?.volume = Float(volume)
        }
    }
    
    public var currentResolvedStreamURL: URL?
    public var currentStreamHeaders: [String: String] = [:]
    
    // Native AVFoundation Player
    private var avPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    private var itemDurationObserver: NSKeyValueObservation?
    private var itemEndObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    @ObservationIgnored private var loadingTimeoutTask: Task<Void, Never>?
    
    public init() {
        configureAudioSession()
        setupAudioObservers()
        restoreLastSession()
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
            
            if type == .began {
                self.pause()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.play()
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
            
            // If headphones unplugged or Bluetooth/AirPods disconnected, pause playback
            if reason == .oldDeviceUnavailable {
                self.pause()
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
    
    private func cancelLoadingTimeout() {
        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = nil
    }
    
    // MARK: - Play Song with Real Diagnostics & 11s Timeout
    public func play(song: Song) {
        cancelLoadingTimeout()
        
        let hdArtwork = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id)
        var upgradedSong = song
        upgradedSong.artworkURL = hdArtwork
        
        // If already loaded this song and was paused, resume
        if currentSong?.id == upgradedSong.id, let player = avPlayer, player.currentItem?.status == .readyToPlay {
            if player.timeControlStatus != .playing {
                player.play()
            }
            return
        }
        
        self.currentSong = upgradedSong
        self.currentTime = 0
        self.duration = upgradedSong.duration > 0 ? upgradedSong.duration : 180
        self.isPlaying = false
        self.isLoading = true
        self.playbackState = .resolving
        self.errorMessage = nil
        
        // Add to history & persistent queue
        LibraryRepository.shared.addHistory(upgradedSong)
        if !queue.contains(where: { $0.id == upgradedSong.id }) {
            queue.append(upgradedSong)
        }
        persistCurrentSession(song: upgradedSong)
        
        // Update lock screen immediately
        updateNowPlaying()
        
        // Preload lyrics & Up Next recommendations in background
        let songForLyrics = upgradedSong
        Task {
            await LyricsService.shared.preloadLyrics(song: songForLyrics)
        }
        fetchRadioQueue(for: upgradedSong.id)
        
        logPlaybackDiagnostics(song: upgradedSong, event: "RESOLVING_STREAM")
        
        // 12s Timeout Protection: UI shows readable error and retry instead of infinite spinner
        loadingTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12 * 1_000_000_000)
            if !Task.isCancelled {
                if self.playbackState == .resolving || self.playbackState == .buffering || self.isLoading {
                    print("[PlayerEngine] ⚠️ Playback timed out after 12 seconds for '\(upgradedSong.title)'")
                    self.playbackState = .failed("Playback timed out. Tap to retry.")
                    self.isLoading = false
                    self.isPlaying = false
                    self.errorMessage = "Playback timed out. Tap to retry."
                    self.logPlaybackDiagnostics(song: upgradedSong, event: "TIMEOUT_EXPIRED")
                }
            }
        }
        
        // Resolve audio-only stream and load native AVPlayer
        Task { @MainActor in
            do {
                let resolved = try await StreamResolutionService.shared.resolveStream(for: upgradedSong)
                guard !Task.isCancelled else { return }
                self.currentResolvedStreamURL = resolved.url
                self.currentStreamHeaders = resolved.headers
                
                self.loadAndPlay(
                    resolved: resolved,
                    for: upgradedSong
                )
            } catch {
                guard !Task.isCancelled else { return }
                self.cancelLoadingTimeout()
                self.isLoading = false
                self.isPlaying = false
                let errText = error.localizedDescription
                self.playbackState = .failed(errText)
                self.errorMessage = errText
                self.logPlaybackDiagnostics(
                    song: upgradedSong,
                    event: "STREAM_RESOLUTION_FAILED",
                    httpStatus: (error as? URLError)?.errorCode
                )
            }
        }
    }
    
    // MARK: - Native AVPlayer Loading & Observation
    private func loadAndPlay(
        resolved: StreamResolutionService.ResolvedStream,
        for song: Song
    ) {
        cleanupItemObservers()
        self.playbackState = .buffering
        
        let streamURL = resolved.url
        var assetOptions: [String: Any] = [:]
        if !resolved.headers.isEmpty {
            assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = resolved.headers
        }
        
        let asset = AVURLAsset(url: streamURL, options: assetOptions.isEmpty ? nil : assetOptions)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Diagnostic log BEFORE giving URL to AVPlayer as required
        logPlaybackDiagnostics(
            song: song,
            event: "BEFORE_AVPLAYER_PLAY",
            streamURL: streamURL,
            httpStatus: resolved.httpStatus,
            mimeType: resolved.mimeType,
            bitrate: resolved.bitrate,
            contentLength: resolved.contentLength,
            playerItem: playerItem
        )
        
        if let existingPlayer = self.avPlayer {
            existingPlayer.replaceCurrentItem(with: playerItem)
        } else {
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            newPlayer.volume = Float(self.volume)
            self.avPlayer = newPlayer
            setupPlayerObservers(player: newPlayer)
        }
        
        setupItemObservers(item: playerItem, expectedDuration: resolved.duration)
        
        // Begin loading and prefetching
        self.avPlayer?.play()
        updateNowPlaying()
    }
    
    private func setupPlayerObservers(player: AVPlayer) {
        // Single Source of Truth: observe player.timeControlStatus
        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] p, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch p.timeControlStatus {
                case .playing:
                    self.cancelLoadingTimeout()
                    self.isPlaying = true
                    self.isLoading = false
                    self.playbackState = .playing
                case .waitingToPlayAtSpecifiedRate:
                    if case .failed = self.playbackState {
                        // Keep error state
                    } else {
                        self.isLoading = true
                        if self.playbackState != .resolving {
                            self.playbackState = .buffering
                        }
                    }
                case .paused:
                    self.isPlaying = false
                    self.isLoading = false
                    if case .failed = self.playbackState {
                        // Retain failed state
                    } else if case .resolving = self.playbackState {
                        // Retain resolving state
                    } else {
                        self.playbackState = .paused
                    }
                @unknown default:
                    break
                }
                self.updateNowPlaying()
                self.logPlaybackDiagnostics(song: self.currentSong, event: "TIMECONTROL_\(p.timeControlStatus.rawValue)")
            }
        }
        
        // Periodic time observer for smooth scrubber & lock screen elapsed time
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let secs = time.seconds
            if !secs.isNaN && secs >= 0 {
                self.currentTime = secs
                NowPlayingManager.shared.updatePlaybackProgress(
                    currentTime: secs,
                    duration: self.duration,
                    isPlaying: self.isPlaying
                )
            }
        }
    }
    
    private func setupItemObservers(item: AVPlayerItem, expectedDuration: TimeInterval) {
        // Item status readyToPlay / failed
        itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] itm, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if itm.status == .readyToPlay {
                    self.cancelLoadingTimeout()
                    self.isLoading = false
                    self.playbackState = .playing
                    self.isPlaying = true
                    
                    let itemDur = itm.duration.seconds
                    if !itemDur.isNaN && itemDur > 0 {
                        self.duration = itemDur
                    } else if expectedDuration > 0 {
                        self.duration = expectedDuration
                    }
                    
                    // Crucial: ensure playback starts upon readyToPlay
                    self.avPlayer?.play()
                    self.updateNowPlaying()
                    self.logPlaybackDiagnostics(song: self.currentSong, event: "ITEM_READY_TO_PLAY")
                } else if itm.status == .failed {
                    self.cancelLoadingTimeout()
                    self.isLoading = false
                    self.isPlaying = false
                    let is403 = itm.error?.localizedDescription.contains("403") == true || (itm.error as? NSError)?.code == -1008
                    let errDesc = itm.error?.localizedDescription ?? "Playback error"
                    self.playbackState = .failed(errDesc)
                    self.errorMessage = errDesc
                    self.logPlaybackDiagnostics(song: self.currentSong, event: "ITEM_FAILED", isExpiredOr403: is403)
                }
            }
        }
        
        // Item duration updates
        itemDurationObserver = item.observe(\.duration, options: [.new]) { [weak self] itm, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let itemDur = itm.duration.seconds
                if !itemDur.isNaN && itemDur > 0 {
                    self.duration = itemDur
                    self.updateNowPlaying()
                }
            }
        }
        
        // Automatically play next song when current track ends
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handleSongDidEnd()
        }
    }
    
    // MARK: - Retry Current Song
    public func retryCurrentSong() {
        guard let song = currentSong else { return }
        self.errorMessage = nil
        self.playbackState = .idle
        self.avPlayer?.replaceCurrentItem(with: nil)
        play(song: song)
    }
    
    // MARK: - Diagnostic Logging Helper
    private func logPlaybackDiagnostics(
        song: Song?,
        event: String,
        streamURL: URL? = nil,
        httpStatus: Int? = nil,
        mimeType: String? = nil,
        bitrate: Int? = nil,
        contentLength: String? = nil,
        playerItem: AVPlayerItem? = nil,
        isExpiredOr403: Bool = false
    ) {
        let s = song ?? currentSong
        let title = s?.title ?? "Unknown"
        let videoId = s?.id ?? "None"
        let streamURLPresent = (streamURL != nil || s?.streamURL != nil || currentResolvedStreamURL != nil) ? "YES" : "NO"
        let effectiveHost = (streamURL ?? currentResolvedStreamURL ?? s?.streamURL)?.host ?? "unknown"
        
        let itemToInspect = playerItem ?? avPlayer?.currentItem
        let statusStr: String
        if let item = itemToInspect {
            switch item.status {
            case .unknown: statusStr = "unknown"
            case .readyToPlay: statusStr = "readyToPlay"
            case .failed: statusStr = "failed: \(item.error?.localizedDescription ?? "nil")"
            @unknown default: statusStr = "other"
            }
        } else {
            statusStr = "no_item"
        }
        
        let timeControlStr: String
        let waitingReason: String
        if let p = avPlayer {
            switch p.timeControlStatus {
            case .paused: timeControlStr = "paused"
            case .waitingToPlayAtSpecifiedRate: timeControlStr = "waitingToPlayAtSpecifiedRate"
            case .playing: timeControlStr = "playing"
            @unknown default: timeControlStr = "other"
            }
            waitingReason = p.reasonForWaitingToPlay?.rawValue ?? "none"
        } else {
            timeControlStr = "no_player"
            waitingReason = "none"
        }
        
        print("""
        [DIAGNOSTICS - \(event)]
        ├─ song title: \(title)
        ├─ videoId: \(videoId)
        ├─ selected mimeType: \(mimeType ?? "audio/mp4")
        ├─ bitrate: \(bitrate.map(String.init) ?? "unknown")
        ├─ contentLength: \(contentLength ?? "unknown")
        ├─ stream URL host: \(effectiveHost)
        ├─ AVPlayerItem.status: \(statusStr)
        ├─ AVPlayerItem.error: \(itemToInspect?.error?.localizedDescription ?? "none")
        ├─ AVPlayer.reasonForWaitingToPlay: \(waitingReason)
        ├─ duration: \(duration)s
        ├─ resolved stream URL present: \(streamURLPresent)
        ├─ HTTP status of stream resolution: \(httpStatus.map(String.init) ?? "N/A")
        ├─ stream URL expired / 403: \(isExpiredOr403 ? "YES" : "NO")
        └─ playbackState: \(playbackState)
        """)
    }
    
    // MARK: - Playback Controls
    public func play() {
        if case .failed = playbackState {
            retryCurrentSong()
            return
        }
        if let p = avPlayer {
            p.play()
        } else if let song = currentSong {
            play(song: song)
        } else if let first = queue.first {
            play(song: first)
        }
    }
    
    public func pause() {
        avPlayer?.pause()
    }
    
    public func togglePlay() {
        if case .failed = playbackState {
            retryCurrentSong()
            return
        }
        if let p = avPlayer {
            if p.timeControlStatus == .playing {
                p.pause()
            } else {
                p.play()
            }
        } else if let song = currentSong {
            play(song: song)
        } else if let first = queue.first {
            play(song: first)
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
            pause()
            seek(to: 0)
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
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        avPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateNowPlaying()
            }
        }
        NowPlayingManager.shared.updatePlaybackProgress(
            currentTime: clamped,
            duration: duration,
            isPlaying: isPlaying
        )
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
    
    private func handleSongDidEnd() {
        if isRepeat {
            seek(to: 0)
            play()
        } else {
            next()
        }
    }
    
    private func updateNowPlaying() {
        NowPlayingManager.shared.updateNowPlaying(
            song: currentSong,
            currentTime: currentTime,
            duration: duration,
            isPlaying: isPlaying
        )
    }
    
    private func fetchRadioQueue(for videoId: String) {
        Task {
            let radioSongs = await RadioService.shared.fetchUpNext(videoId: videoId)
            await MainActor.run {
                self.appendRadioSongs(radioSongs)
            }
        }
    }
    
    private func appendRadioSongs(_ songs: [Song]) {
        for song in songs {
            if !queue.contains(where: { $0.id == song.id }) {
                queue.append(song)
            }
        }
    }
    
    private func cleanupItemObservers() {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        itemDurationObserver?.invalidate()
        itemDurationObserver = nil
        if let endObs = itemEndObserver {
            NotificationCenter.default.removeObserver(endObs)
            itemEndObserver = nil
        }
    }
    
    private func cleanupPlayer() {
        cancelLoadingTimeout()
        cleanupItemObservers()
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        avPlayer?.pause()
        avPlayer = nil
    }
}
