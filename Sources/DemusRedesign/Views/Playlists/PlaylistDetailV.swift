import SwiftUI

// MARK: - PlaylistDetailV (Apple Music Playlist Detail View)
/// Displays a playlist with header artwork, description, Play/Shuffle actions, tracks, and persistence.
public struct PlaylistDetailV: View {
    public let playlist: Playlist
    @Bindable public var player: PlayerEngine = .shared
    
    @State private var currentPlaylist: Playlist
    
    public init(playlist: Playlist) {
        self.playlist = playlist
        self._currentPlaylist = State(initialValue: playlist)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Artwork
                ZStack {
                    if let rawUrl = currentPlaylist.artworkURL, let url = ImageHelper.highResArtworkURL(from: rawUrl, resolution: .card) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            placeholderImage
                        }
                    } else {
                        placeholderImage
                    }
                }
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusLargeCard, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppleMusicTheme.radiusLargeCard, style: .continuous)
                        .stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
                .padding(.top, 10)
                
                // Playlist Info
                VStack(spacing: 6) {
                    Text(currentPlaylist.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppleMusicTheme.label)
                        .multilineTextAlignment(.center)
                    
                    if let desc = currentPlaylist.descriptionText, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                
                // Play & Shuffle Action Buttons
                if !currentPlaylist.songs.isEmpty {
                    HStack(spacing: 16) {
                        Button {
                            player.playAll(songs: currentPlaylist.songs, startingAt: 0, shuffle: false)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Play")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppleMusicTheme.secondarySystemBackground)
                            .foregroundStyle(AppleMusicTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.appleMusicCard)
                        
                        Button {
                            player.playAll(songs: currentPlaylist.songs, startingAt: 0, shuffle: true)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Shuffle")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppleMusicTheme.secondarySystemBackground)
                            .foregroundStyle(AppleMusicTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.appleMusicCard)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Track List
                if !currentPlaylist.songs.isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(currentPlaylist.songs.enumerated()), id: \.element.id) { index, song in
                            SongRow(
                                song: song,
                                isCurrentPlaying: player.currentSong?.id == song.id
                            ) {
                                player.playAll(songs: currentPlaylist.songs, startingAt: index, shuffle: false)
                            } onMenu: {
                                // Handled by context menu or custom menu
                            }
                            .contextMenu {
                                Button {
                                    player.playNext(song)
                                } label: {
                                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                                }
                                
                                Button {
                                    player.addToQueue(song)
                                } label: {
                                    Label("Play Later", systemImage: "text.line.last.and.arrowtriangle.forward")
                                }
                                
                                Button {
                                    player.toggleFavorite(for: song.id)
                                } label: {
                                    Label(song.isFavorite ? "Unfavorite" : "Favorite", systemImage: song.isFavorite ? "star.fill" : "star")
                                }
                                
                                if currentPlaylist.isUserCreated {
                                    Button(role: .destructive) {
                                        LibraryRepository.shared.removeSong(songId: song.id, from: currentPlaylist.id)
                                        currentPlaylist.songs.removeAll(where: { $0.id == song.id })
                                    } label: {
                                        Label("Remove from Playlist", systemImage: "trash")
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 8)
                } else {
                    ContentUnavailableView {
                        Label("Playlist is Empty", systemImage: "music.note.list")
                    } description: {
                        Text("Add tracks to this playlist from search results or your library.")
                    }
                    .padding(.top, 40)
                }
                
                Spacer(minLength: 100) // Padding for CompactPlayer
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let updated = LibraryRepository.shared.playlists.first(where: { $0.id == playlist.id }) {
                self.currentPlaylist = updated
            }
        }
    }
    
    private var placeholderImage: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
        }
    }
}
