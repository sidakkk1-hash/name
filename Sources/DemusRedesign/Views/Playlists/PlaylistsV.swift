import SwiftUI

// MARK: - PlaylistsV (Apple Music Playlists Screen)
/// Reconstructed Playlists screen with 2-column adaptive grid of squircle playlist cards,
/// "New Playlist" action, and empty state support.
public struct PlaylistsV: View {
    @State private var playlists: [Playlist] = LibraryRepository.shared.playlists
    @State private var showingNewPlaylistAlert: Bool = false
    @State private var newPlaylistName: String = ""
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                if playlists.isEmpty {
                    // Polished Empty State
                    ContentUnavailableView {
                        Label("No Playlists", systemImage: "music.note.list")
                    } description: {
                        Text("Playlists you create or import will appear here.")
                    } actions: {
                        Button {
                            showingNewPlaylistAlert = true
                        } label: {
                            Text("New Playlist")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(AppleMusicTheme.accent)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(playlists) { playlist in
                            NavigationLink {
                                PlaylistDetailV(playlist: playlist)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    // Square Artwork
                                    ZStack {
                                        if let url = playlist.artworkURL {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                case .failure, .empty:
                                                    placeholderArtwork
                                                @unknown default:
                                                    placeholderArtwork
                                                }
                                            }
                                        } else {
                                            placeholderArtwork
                                        }
                                    }
                                    .aspectRatio(1.0, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusCard, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppleMusicTheme.radiusCard, style: .continuous)
                                            .stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                                    
                                    // Title & Count
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(AppleMusicTheme.label)
                                            .lineLimit(1)
                                        
                                        Text("\(playlist.songs.count) Songs")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.appleMusicCard)
                            .contextMenu {
                                if !playlist.songs.isEmpty {
                                    Button {
                                        player.playAll(songs: playlist.songs, startingAt: 0, shuffle: false)
                                    } label: {
                                        Label("Play", systemImage: "play.fill")
                                    }
                                }
                                
                                Button(role: .destructive) {
                                    withAnimation {
                                        LibraryRepository.shared.deletePlaylist(id: playlist.id)
                                        playlists.removeAll(where: { $0.id == playlist.id })
                                    }
                                } label: {
                                    Label("Delete Playlist", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 90) // Safe padding for CompactPlayer
                }
            }
            .navigationTitle("Playlists")
            .onAppear {
                self.playlists = LibraryRepository.shared.playlists
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewPlaylistAlert = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppleMusicTheme.accent)
                    }
                }
            }
            .alert("New Playlist", isPresented: $showingNewPlaylistAlert) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) { newPlaylistName = "" }
                Button("Create") {
                    if !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty {
                        let newPl = Playlist(
                            title: newPlaylistName,
                            descriptionText: "Created by you",
                            artworkURL: nil,
                            songs: []
                        )
                        LibraryRepository.shared.addPlaylist(newPl)
                        playlists.insert(newPl, at: 0)
                        newPlaylistName = ""
                    }
                }
            }
        }
    }
    
    private var placeholderArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
        }
    }
}
