import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - EqualizerBarsView
public struct EqualizerBarsView: View {
    public let isPlaying: Bool
    @State private var bar1: CGFloat = 0.3
    @State private var bar2: CGFloat = 0.7
    @State private var bar3: CGFloat = 0.4
    
    public init(isPlaying: Bool) {
        self.isPlaying = isPlaying
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 2.2) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppleMusicTheme.accent)
                .frame(width: 2.8, height: isPlaying ? max(3, bar1 * 13) : 3)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppleMusicTheme.accent)
                .frame(width: 2.8, height: isPlaying ? max(4, bar2 * 13) : 6)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppleMusicTheme.accent)
                .frame(width: 2.8, height: isPlaying ? max(3, bar3 * 13) : 4)
        }
        .frame(height: 14)
        .onAppear {
            if isPlaying {
                animate()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                animate()
            }
        }
    }
    
    private func animate() {
        withAnimation(.easeInOut(duration: 0.38).repeatForever(autoreverses: true)) {
            bar1 = 1.0
            bar2 = 0.3
            bar3 = 0.9
        }
    }
}

// MARK: - MiniPlayer (Floating Liquid Glass Capsule)
/// Floating modern Apple Music mini player capsule with liquid glass styling,
/// bouncing animated waveform visualizer, swipe gestures, and tactile haptic feedback.
public struct MiniPlayer: View {
    @Bindable public var player: PlayerEngine
    @Bindable public var mainTVM: MainTVM
    
    public init(player: PlayerEngine = .shared, mainTVM: MainTVM = .shared) {
        self.player = player
        self.mainTVM = mainTVM
    }
    
    public var body: some View {
        if let currentSong = player.currentSong {
            ZStack(alignment: .bottom) {
                // Main capsule body
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    withAnimation(AppleMusicTheme.springAnimation) {
                        mainTVM.isNowPlayingPresented = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Artwork Left
                        ZStack {
                            if let url = ImageHelper.highResArtworkURL(from: currentSong.artworkURL, videoId: currentSong.id) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure, .empty:
                                        thumbnailPlaceholder
                                    @unknown default:
                                        thumbnailPlaceholder
                                    }
                                }
                            } else {
                                thumbnailPlaceholder
                            }
                        }
                        .frame(width: AppleMusicTheme.miniPlayerArtworkSize, height: AppleMusicTheme.miniPlayerArtworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusThumbnail, style: .continuous))
                        .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3)
                        
                        // Title + Artist Center
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(currentSong.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppleMusicTheme.label)
                                    .lineLimit(1)
                                
                                if player.isPlaying {
                                    EqualizerBarsView(isPlaying: true)
                                }
                            }
                            
                            Text(currentSong.artistName)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Play/Pause Action with Haptic
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            player.togglePlay()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundStyle(AppleMusicTheme.label)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.appleMusicPlayButton)
                        
                        // Next Track Action with Haptic
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            player.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(AppleMusicTheme.label)
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.appleMusicPlayButton)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: AppleMusicTheme.miniPlayerHeight)
                    // Liquid Glassmorphic Backdrop
                    .background(
                        ZStack {
                            Rectangle().fill(.ultraThinMaterial)
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusMiniPlayer, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppleMusicTheme.radiusMiniPlayer, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                    )
                }
                .buttonStyle(.appleMusicCard)
                // Swipe Left/Right Gesture for Track Change
                .simultaneousGesture(
                    DragGesture(minimumDistance: 25)
                        .onEnded { value in
                            if value.translation.width < -40 {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                player.next()
                            } else if value.translation.width > 40 {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                player.prev()
                            }
                        }
                )
                
                // Embedded Thin Progress Indicator along bottom edge
                GeometryReader { geo in
                    let progress = player.duration > 0 ? (player.currentTime / player.duration) : 0
                    Capsule()
                        .fill(AppleMusicTheme.accent)
                        .frame(width: max(0, min(geo.size.width * progress, geo.size.width)), height: 2.2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(y: AppleMusicTheme.miniPlayerHeight - 2.2)
                }
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusMiniPlayer, style: .continuous))
            }
            .frame(height: AppleMusicTheme.miniPlayerHeight)
            .shadow(
                color: Color.black.opacity(0.28),
                radius: 14,
                x: 0,
                y: 8
            )
            .padding(.horizontal, AppleMusicTheme.miniPlayerHorizontalPadding)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Image(systemName: "music.note")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
    }
}
