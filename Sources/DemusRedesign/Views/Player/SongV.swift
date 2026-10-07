import SwiftUI

// MARK: - SongV (Full Now Playing Modal)
/// Full Apple Music-style Now Playing modal screen.
/// Features dynamic blurred artwork background, squircle interactive scaling artwork,
/// bold typography, precision scrubber, dominant playback controls, volume slider, and bottom utility toolbar.
public struct SongV: View {
    @Bindable public var player: PlayerEngine
    @Bindable public var mainTVM: MainTVM
    @State private var songVM = SongVM()
    @State private var isCreditsPresented: Bool = false
    @State private var isSharePresented: Bool = false
    @State private var isAudioQualitySheetPresented: Bool = false
    @State private var sleepTimerLabel: String? = nil
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
        .sheet(isPresented: $isCreditsPresented) {
            if let song = player.currentSong {
                SongCreditsSheet(song: song)
                    .presentationBackground(.ultraThinMaterial)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $isSharePresented) {
            if let song = player.currentSong {
                SongShareStorySheet(song: song)
                    .presentationBackground(.ultraThinMaterial)
                    .presentationDragIndicator(.visible)
            }
        }
        .alert("Lossless Audio", isPresented: $isAudioQualitySheetPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This track is playing in authentic high-bitrate Lossless Audio (24-bit / 48 kHz ALAC / AAC stream) with Apple Digital Master sound fidelity.")
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
                    
                    Button {
                        isCreditsPresented = true
                    } label: {
                        Label("View Credits", systemImage: "info.circle")
                    }
                    
                    Button {
                        isSharePresented = true
                    } label: {
                        Label("Share Story Card...", systemImage: "square.and.arrow.up")
                    }
                    
                    Menu {
                        Button("15 Minutes") { setSleepTimer(minutes: 15) }
                        Button("30 Minutes") { setSleepTimer(minutes: 30) }
                        Button("45 Minutes") { setSleepTimer(minutes: 45) }
                        Button("60 Minutes") { setSleepTimer(minutes: 60) }
                        Button("End of Song") { setSleepTimer(minutes: -1) }
                        if sleepTimerLabel != nil {
                            Button(role: .destructive) {
                                sleepTimerLabel = nil
                            } label: {
                                Text("Turn Off")
                            }
                        }
                    } label: {
                        Label(sleepTimerLabel != nil ? "Sleep Timer (\(sleepTimerLabel!))" : "Sleep Timer", systemImage: "moon.stars")
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
                    
                    Section("Audio Engine") {
                        Label(player.activeEngineName, systemImage: player.isUsingNativeEngine ? "waveform.badge.checkmark" : "globe")
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
                
                HStack(spacing: 8) {
                    Text(currentSong.artistName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                    
                    Button {
                        isAudioQualitySheetPresented = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "waveform")
                                .font(.system(size: 8, weight: .bold))
                            Text("Lossless")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
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
    
    private func setSleepTimer(minutes: Int) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        if minutes == -1 {
            sleepTimerLabel = "End of Song"
        } else {
            sleepTimerLabel = "\(minutes)m"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
                if sleepTimerLabel != nil {
                    player.pause()
                    sleepTimerLabel = nil
                }
            }
        }
    }
}
