import SwiftUI

// MARK: - SongV (Full Now Playing Modal)
/// Full Apple Music-style Now Playing modal screen.
/// Features dynamic blurred artwork background, squircle interactive scaling artwork,
/// bold typography, precision scrubber, dominant playback controls, volume slider, and bottom utility toolbar.
public struct SongV: View {
    @Bindable public var player: PlayerEngine
    @Bindable public var mainTVM: MainTVM
    @State private var songVM = SongVM()
    @Environment(\.dismiss) private var dismiss
    
    public init(player: PlayerEngine = .shared, mainTVM: MainTVM = .shared) {
        self.player = player
        self.mainTVM = mainTVM
    }
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Dynamic Artwork Background
                DynamicPlayerBackground(
                    artworkURL: player.currentSong?.artworkURL,
                    blurRadius: 65,
                    darkOverlayOpacity: 0.50
                )
                
                // Now Playing Content
                VStack(spacing: 0) {
                    // Header Bar (Dismiss Chevron, Drag Pill, Menu)
                    headerBar
                        .padding(.top, 10)
                        .padding(.horizontal, 20)
                    
                    Spacer(minLength: 16)
                    
                    // Center Large Squircle Artwork
                    NowPlayingArtwork(
                        song: player.currentSong,
                        isPlaying: player.isPlaying,
                        targetWidth: proxy.size.width
                    )
                    
                    Spacer(minLength: 24)
                    
                    // Song Info + Favorite / Menu
                    if let currentSong = player.currentSong {
                        songInfoSection(currentSong: currentSong)
                            .padding(.horizontal, 28)
                    }
                    
                    // Scrubber Bar
                    AppleMusicScrubber(player: player)
                        .padding(.horizontal, 28)
                        .padding(.top, 20)
                    
                    // Dominant Playback Controls
                    AppleMusicPlaybackControls(player: player)
                        .padding(.top, 24)
                    
                    // Volume Slider
                    AppleMusicVolumeSlider()
                        .padding(.horizontal, 32)
                        .padding(.top, 28)
                    
                    Spacer(minLength: 16)
                    
                    // Secondary Actions (Lyrics, AirPlay, Queue)
                    AppleMusicSecondaryToolbar(mainTVM: mainTVM, player: player)
                        .padding(.horizontal, 48)
                        .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $mainTVM.isLyricsPresented) {
            SongLyricsV(player: player)
                .presentationBackground(.ultraThinMaterial)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $mainTVM.isQueuePresented) {
            QueueV(player: player)
                .presentationBackground(.ultraThinMaterial)
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Centered Drag Grabber Pill
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 36, height: 5)
            
            Spacer()
            
            // Options Menu Button
            Menu {
                if let song = player.currentSong {
                    Button {
                        player.toggleFavorite(for: song.id)
                    } label: {
                        Label(
                            LibraryRepository.shared.isFavorite(id: song.id) ? "Unfavorite" : "Favorite",
                            systemImage: LibraryRepository.shared.isFavorite(id: song.id) ? "star.fill" : "star"
                        )
                    }
                    
                    if LibraryRepository.shared.isInLibrary(id: song.id) {
                        Button(role: .destructive) {
                            LibraryRepository.shared.removeSong(id: song.id)
                        } label: {
                            Label("Delete from Library", systemImage: "trash")
                        }
                    } else {
                        Button {
                            LibraryRepository.shared.addSong(song)
                        } label: {
                            Label("Add to Library", systemImage: "plus")
                        }
                    }
                    
                    if !LibraryRepository.shared.playlists.isEmpty {
                        Menu {
                            ForEach(LibraryRepository.shared.playlists) { pl in
                                Button {
                                    LibraryRepository.shared.addSong(song, to: pl.id)
                                } label: {
                                    Text(pl.title)
                                }
                            }
                        } label: {
                            Label("Add to a Playlist...", systemImage: "text.badge.plus")
                        }
                    }
                    
                    ShareLink(item: "\(song.title) - \(song.artistName)") {
                        Label("Share Song...", systemImage: "square.and.arrow.up")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Song Info Section
    private func songInfoSection(currentSong: Song) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentSong.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(currentSong.artistName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Favorite Button
            Button {
                player.toggleFavorite(for: currentSong.id)
            } label: {
                Image(systemName: currentSong.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(currentSong.isFavorite ? AppleMusicTheme.accent : .white.opacity(0.7))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
    }
}
