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
        let artworkSize = min(targetWidth * 0.82, 360)
        
        ZStack {
            // Ambient Colored Aura Shadow (casts vibrant colors matching artwork)
            if let song = song, let url = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id, resolution: .card) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: artworkSize * 0.86, height: artworkSize * 0.86)
                        .blur(radius: isPlaying ? 32 : 16)
                        .opacity(isPlaying ? 0.65 : 0.20)
                        .offset(y: isPlaying ? 16 : 8)
                } placeholder: {
                    EmptyView()
                }
            }
            
            // Front High-Res Artwork
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
                color: Color.black.opacity(isPlaying ? 0.38 : 0.20),
                radius: isPlaying ? 24 : 14,
                x: 0,
                y: isPlaying ? 14 : 7
            )
        }
        // Dynamic scale compression on pause (1.0 playing -> 0.84 paused)
        .scaleEffect(isPlaying ? 1.0 : 0.84)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isPlaying)
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
