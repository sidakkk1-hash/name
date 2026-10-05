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
        // Controlled isolation: temporarily disabled to verify foreground playback stability
    }
    
    // MARK: - Update Lock Screen Now Playing Info
    public func updateNowPlaying(
        song: Song?,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool
    ) {
        // Controlled isolation: temporarily disabled to verify foreground playback stability
    }
}
