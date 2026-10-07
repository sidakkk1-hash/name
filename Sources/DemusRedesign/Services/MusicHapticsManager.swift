import Foundation

// MARK: - MusicHapticsManager (Completely Disabled / Inert)
public final class MusicHapticsManager: @unchecked Sendable {
    public static let shared = MusicHapticsManager()
    public var isEnabled: Bool = false
    public init() {}
    public func handlePlaybackStateChange(isPlaying: Bool) {}
    public func triggerTrackChangeHaptic() {}
    public func stop() {}
}
