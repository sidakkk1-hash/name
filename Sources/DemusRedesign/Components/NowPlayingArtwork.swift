import SwiftUI

// MARK: - NowPlayingArtwork
/// The signature Apple Music squircle artwork view.
/// Occupies 75-82% of screen width, features soft ambient drop shadows,
/// and includes the iconic subtle scale compression (1.0 playing -> 0.85 paused) with spring animation.
public struct NowPlayingArtwork: View {
    public let song: Song?
    public var isPlaying: Bool
    public var targetWidth: CGFloat
    
    @AppStorage("demus_animated_artwork") private var animatedArtworkSetting: String = "Wi-Fi & Cellular"
    @State private var auraPulse: Bool = false
    
    public init(song: Song?, isPlaying: Bool, targetWidth: CGFloat) {
        self.song = song
        self.isPlaying = isPlaying
        self.targetWidth = targetWidth
    }
    
    private var isAnimatedArtworkActive: Bool {
        animatedArtworkSetting != "Off"
    }
    
    public var body: some View {
        let artworkSize = min(targetWidth * 0.82, 360)
        
        ZStack {
            // Ambient Artwork Bloom / Animated Living Aura
            if let song = song, let url = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id, resolution: .card) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: artworkSize * (isAnimatedArtworkActive && isPlaying ? (auraPulse ? 0.92 : 0.86) : 0.86),
                               height: artworkSize * (isAnimatedArtworkActive && isPlaying ? (auraPulse ? 0.92 : 0.86) : 0.86))
                        .blur(radius: isPlaying ? 34 : 16)
                        .opacity(isPlaying ? (auraPulse ? 0.75 : 0.55) : 0.20)
                        .offset(y: isPlaying ? 16 : 8)
                        .animation(
                            isAnimatedArtworkActive && isPlaying ? .easeInOut(duration: 3.5).repeatForever(autoreverses: true) : .default,
                            value: auraPulse
                        )
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
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.easeInOut(duration: 0.45), value: song?.id)
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
        // Apple Music Exact Scale Curve: 1.00x Play, 0.85x Pause with Spring Animation
        .scaleEffect(isPlaying ? 1.00 : 0.85)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isPlaying)
        .onAppear {
            if isAnimatedArtworkActive && isPlaying {
                auraPulse = true
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if isAnimatedArtworkActive && playing {
                auraPulse = true
            } else {
                auraPulse = false
            }
        }
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
