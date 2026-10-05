import Foundation
#if canImport(MediaPlayer)
import MediaPlayer
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - NowPlayingManager
/// Manages native iOS Lock Screen Now Playing metadata, Control Center, and Dynamic Island system integration.
public final class NowPlayingManager: @unchecked Sendable {
    public static let shared = NowPlayingManager()
    
    private var isConfigured: Bool = false
    private var lastArtworkSongId: String?
    private var cachedArtwork: MPMediaItemArtwork?
    
    public init() {}
    
    // MARK: - Setup Remote Command Center Handlers
    public func setupRemoteCommands(player: PlayerEngine) {
        #if canImport(MediaPlayer)
        guard !isConfigured else { return }
        isConfigured = true
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 1. Play Command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.playCommand.addTarget { _ in
            player.play()
            return .success
        }
        
        // 2. Pause Command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.pauseCommand.addTarget { _ in
            player.pause()
            return .success
        }
        
        // 3. Toggle Play/Pause Command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            player.togglePlay()
            return .success
        }
        
        // 4. Next Track Command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.addTarget { _ in
            player.next()
            return .success
        }
        
        // 5. Previous Track Command
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.addTarget { _ in
            player.prev()
            return .success
        }
        
        // 6. Change Playback Position (Scrubbing on Lock Screen & Control Center)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            player.seek(to: posEvent.positionTime)
            return .success
        }
        #endif
    }
    
    // MARK: - Update Lock Screen Now Playing Info
    public func updateNowPlaying(
        song: Song?,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool
    ) {
        #if canImport(MediaPlayer)
        guard let song = song else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            cachedArtwork = nil
            lastArtworkSongId = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artistName,
            MPMediaItemPropertyAlbumTitle: song.albumTitle ?? song.title,
            MPMediaItemPropertyPlaybackDuration: max(1.0, duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        if lastArtworkSongId == song.id, let cached = cachedArtwork {
            info[MPMediaItemPropertyArtwork] = cached
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // Load artwork asynchronously in background
        if lastArtworkSongId != song.id {
            lastArtworkSongId = song.id
            cachedArtwork = nil
            
            if let artworkURL = song.artworkURL {
                Task {
                    guard let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                          let image = UIImage(data: data) else { return }
                    
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    
                    await MainActor.run {
                        guard self.lastArtworkSongId == song.id else { return }
                        self.cachedArtwork = artwork
                        var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        current[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                    }
                }
            }
        }
        #endif
    }
    
    // MARK: - Periodic Playback Progress Sync
    public func updatePlaybackProgress(
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool
    ) {
        #if canImport(MediaPlayer)
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = max(1.0, duration)
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }
    
    public func clearNowPlaying() {
        #if canImport(MediaPlayer)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        cachedArtwork = nil
        lastArtworkSongId = nil
        #endif
    }
}
