import Foundation
#if canImport(MediaPlayer)
import MediaPlayer
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - NowPlayingManager
/// Manages iOS Lock Screen Now Playing metadata, Control Center, and Dynamic Island integration.
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
        
        let center = MPRemoteCommandCenter.shared()
        
        // Play Command
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            if !player.isPlaying {
                player.togglePlay()
            }
            return .success
        }
        
        // Pause Command
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { _ in
            if player.isPlaying {
                player.togglePlay()
            }
            return .success
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
            cachedArtwork = nil
            lastArtworkSongId = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artistName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: currentTime),
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: duration > 0 ? duration : 180),
            MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: isPlaying ? 1.0 : 0.0)
        ]
        
        if let album = song.albumTitle, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        
        // Reuse cached artwork if for the same song
        if lastArtworkSongId == song.id, let cached = cachedArtwork {
            info[MPMediaItemPropertyArtwork] = cached
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // Load artwork if needed
        if lastArtworkSongId != song.id {
            lastArtworkSongId = song.id
            cachedArtwork = nil
            
            if let artworkURL = song.artworkURL {
                #if canImport(UIKit)
                // First check in-memory cache safely
                if let cachedImage = ImageCache.shared.get(for: artworkURL),
                   cachedImage.size.width > 0, cachedImage.size.height > 0 {
                    let artwork = MPMediaItemArtwork(boundsSize: cachedImage.size) { _ in cachedImage }
                    self.cachedArtwork = artwork
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    return
                }
                
                // Otherwise fetch asynchronously
                let songId = song.id
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: artworkURL)
                        if let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 {
                            ImageCache.shared.set(image, for: artworkURL)
                            await MainActor.run {
                                guard self.lastArtworkSongId == songId else { return }
                                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                                self.cachedArtwork = artwork
                                var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                                current[MPMediaItemPropertyArtwork] = artwork
                                MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                            }
                        }
                    } catch {}
                }
                #endif
            }
        }
        #endif
    }
}
