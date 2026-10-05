import SwiftUI

// MARK: - NowPlayingArtwork
/// The signature Apple Music squircle artwork view.
/// Occupies 75-82% of screen width, features soft ambient drop shadows,
/// and includes the iconic subtle scale compression (1.0 playing -> 0.85 paused) with spring animation.
public struct NowPlayingArtwork: View {
    public let song: Song?
    public var isPlaying: Bool
    public var targetWidth: CGFloat
    
    public init(song: Song?, isPlaying: Bool, targetWidth: CGFloat) {
        self.song = song
        self.isPlaying = isPlaying
        self.targetWidth = targetWidth
    }
    
    public var body: some View {
        let artworkSize = min(targetWidth * 0.80, 360)
        
        ZStack {
            if let song = song, let url = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id, resolution: .full) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    defaultArtworkPlaceholder(size: artworkSize)
                }
            } else {
                defaultArtworkPlaceholder(size: artworkSize)
            }
        }
        .id(song?.id)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.4), value: song?.id)
        .frame(width: artworkSize, height: artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusArtworkNowPlaying, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppleMusicTheme.radiusArtworkNowPlaying, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        // Apple Music Soft Ambient Shadow
        .shadow(
            color: Color.black.opacity(isPlaying ? 0.40 : 0.22),
            radius: isPlaying ? 28 : 16,
            x: 0,
            y: isPlaying ? 16 : 8
        )
        // Dynamic scale compression on pause
        .scaleEffect(isPlaying ? 1.0 : 0.84)
        .animation(.spring(response: 0.42, dampingFraction: 0.72), value: isPlaying)
    }
    
    private func defaultArtworkPlaceholder(size: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.35), Color.black.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.32, weight: .light))
                .foregroundStyle(.white.opacity(0.65))
        }
    }
}
