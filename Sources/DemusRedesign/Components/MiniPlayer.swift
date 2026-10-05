import SwiftUI

// MARK: - MiniPlayer
/// Floating modern Apple Music mini player capsule.
/// Positioned directly above the bottom tab bar.
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
                        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                        
                        // Title + Artist Center
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentSong.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppleMusicTheme.label)
                                .lineLimit(1)
                            
                            Text(currentSong.artistName)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Play/Pause Action
                        Button {
                            player.togglePlay()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(AppleMusicTheme.label)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.appleMusicPlayButton)
                        
                        // Next Track Action
                        Button {
                            player.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppleMusicTheme.label)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.appleMusicPlayButton)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: AppleMusicTheme.miniPlayerHeight)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusMiniPlayer, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppleMusicTheme.radiusMiniPlayer, style: .continuous)
                            .stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.appleMusicCard)
                
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
                color: AppleMusicTheme.miniPlayerShadow.color,
                radius: AppleMusicTheme.miniPlayerShadow.radius,
                x: AppleMusicTheme.miniPlayerShadow.x,
                y: AppleMusicTheme.miniPlayerShadow.y
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
