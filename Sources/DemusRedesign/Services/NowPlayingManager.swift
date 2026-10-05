import Foundation
#if canImport(MediaPlayer)
import MediaPlayer
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - NowPlayingManager
/// Manages iOS Lock Screen Now Playing metadata and Remote Command Center handlers.
public final class NowPlayingManager: @unchecked Sendable {
    public static let shared = NowPlayingManager()
    
    private var isConfigured: Bool = false
    
    public init() {}
    
    // MARK: - Setup Remote Command Center Handlers
    public func setupRemoteCommands(player: PlayerEngine) {
        #if canImport(MediaPlayer)
        guard !isConfigured else { return }
        isConfigured = true
        
        let center = MPRemoteCommandCenter.shared()
        
        // Play Command
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            if !player.isPlaying {
                player.togglePlay()
                return .success
            }
            return .commandFailed
        }
        
        // Pause Command
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { _ in
            if player.isPlaying {
                player.togglePlay()
                return .success
            }
            return .commandFailed
        }
        
        // Toggle Play/Pause Command
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { _ in
            player.togglePlay()
            return .success
        }
        
        // Next Track Command
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { _ in
            player.next()
            return .success
        }
        
        // Previous Track Command
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { _ in
            player.prev()
            return .success
        }
        
        // Scrubber / Position Seeking from Lock Screen
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                player.seek(to: positionEvent.positionTime)
                return .success
            }
            return .commandFailed
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
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artistName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : 180,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        if let album = song.albumTitle, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // Asynchronously load artwork for Lock Screen
        if let artworkURL = song.artworkURL {
            Task {
                if let data = try? await HTTPClient.shared.get(url: artworkURL),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    await MainActor.run {
                        var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        current[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                    }
                }
            }
        }
        #endif
    }
}
