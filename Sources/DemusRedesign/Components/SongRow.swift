import SwiftUI

// MARK: - SongRow
/// Signature Apple Music library and search track list row.
/// Features 52pt squircle artwork, primary title, explicit badge,
/// tappable artist and album links, playing state indicator, and ellipsis menu.
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
        HStack(spacing: 14) {
            // Artwork Thumbnail (Tapping plays song)
            Button {
                onPlay()
            } label: {
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
                    
                    // Animated playback waveform overlay if currently playing
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
            }
            .buttonStyle(.plain)
            
            // Track & Metadata Information
            VStack(alignment: .leading, spacing: 3) {
                // Song Title + Explicit Badge (Tapping plays song)
                Button {
                    onPlay()
                } label: {
                    HStack(spacing: 6) {
                        Text(song.title)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(isCurrentPlaying ? AppleMusicTheme.accent : AppleMusicTheme.label)
                            .lineLimit(1)
                        
                        if song.isExplicit {
                            Text("E")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Tappable Subtitle: Artist Name -> ArtistV, Album -> AlbumV
                HStack(spacing: 4) {
                    if let aBrowseId = song.artistBrowseId, !aBrowseId.isEmpty, aBrowseId != "artist-yt" {
                        NavigationLink(value: AppRoute.artist(aBrowseId)) {
                            Text(song.artistName)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(song.artistName)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .lineLimit(1)
                    }
                    
                    if let album = song.albumTitle, !album.isEmpty {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(AppleMusicTheme.tertiaryLabel)
                        
                        if let aId = song.albumBrowseId, !aId.isEmpty {
                            NavigationLink(value: AppRoute.album(aId)) {
                                Text(album)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(album)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Favorite Star if marked
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
