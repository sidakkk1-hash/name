import SwiftUI

// MARK: - SongRow
/// Signature Apple Music library and search track list row.
/// Features 52pt squircle artwork, primary title, secondary metadata, playing state indicator, and ellipsis menu.
public struct SongRow: View {
    public let song: Song
    public var isCurrentPlaying: Bool
    public var onPlay: () -> Void
    public var onMenu: (() -> Void)?
    
    public init(
        song: Song,
        isCurrentPlaying: Bool = false,
        onPlay: @escaping () -> Void,
        onMenu: (() -> Void)? = nil
    ) {
        self.song = song
        self.isCurrentPlaying = isCurrentPlaying
        self.onPlay = onPlay
        self.onMenu = onMenu
    }
    
    public var body: some View {
        Button {
            onPlay()
        } label: {
            HStack(spacing: 14) {
                // Artwork Thumbnail
                ZStack {
                    if let url = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id, resolution: .thumbnail) {
                        CachedAsyncImage(url: url) { img in
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            placeholderImage
                        }
                    } else {
                        placeholderImage
                    }
                    
                    // Subtle playback indicator overlay if currently playing
                    if isCurrentPlaying {
                        ZStack {
                            Color.black.opacity(0.4)
                            Image(systemName: "waveform")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.accent)
                                .symbolEffect(.variableColor.iterative.reversing)
                        }
                    }
                }
                .frame(width: AppleMusicTheme.songRowArtworkSize, height: AppleMusicTheme.songRowArtworkSize)
                .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusThumbnail, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                
                // Track & Artist Information
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(isCurrentPlaying ? AppleMusicTheme.accent : AppleMusicTheme.label)
                        .lineLimit(1)
                    
                    Text(songSubtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Favorite Heart if loved
                if song.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppleMusicTheme.accent)
                }
                
                // Ellipsis Action Menu
                Menu {
                    Button {
                        PlayerEngine.shared.playNext(song)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    
                    Button {
                        PlayerEngine.shared.addToQueue(song)
                    } label: {
                        Label("Play Later", systemImage: "text.line.last.and.arrowtriangle.forward")
                    }
                    
                    Button {
                        PlayerEngine.shared.toggleFavorite(for: song.id)
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
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.appleMusicCard)
        .contextMenu {
            Button {
                PlayerEngine.shared.playNext(song)
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                PlayerEngine.shared.addToQueue(song)
            } label: {
                Label("Play Later", systemImage: "text.line.last.and.arrowtriangle.forward")
            }
            
            Button {
                PlayerEngine.shared.toggleFavorite(for: song.id)
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
        }
    }
    
    private var songSubtitle: String {
        if let album = song.albumTitle, !album.isEmpty {
            return "\(song.artistName) — \(album)"
        }
        return song.artistName
    }
    
    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
    }
}
