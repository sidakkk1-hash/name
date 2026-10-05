import SwiftUI

// MARK: - ArtistV (Apple Music Artist Detail View)
/// Displays an artist with hero banner, name overlay, Play button, Popular tracks, and Discography / Albums carousel.
public struct ArtistV: View {
    public let artist: Artist
    @Bindable public var player: PlayerEngine = .shared
    
    @State private var currentArtist: Artist
    @State private var isLoading: Bool = false
    
    public init(artist: Artist) {
        self.artist = artist
        self._currentArtist = State(initialValue: artist)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large Hero Artist Banner
                ZStack(alignment: .bottomLeading) {
                    if let rawUrl = currentArtist.artworkURL, let url = ImageHelper.highResArtworkURL(from: rawUrl, resolution: .card) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            heroPlaceholder
                        }
                    } else {
                        heroPlaceholder
                    }
                    
                    // Gradient overlay to guarantee legible white text
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.8)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    
                    // Hero Overlay Content
                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentArtist.name)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        
                        if !currentArtist.topSongs.isEmpty {
                            HStack(spacing: 12) {
                                Button {
                                    player.playAll(songs: currentArtist.topSongs, startingAt: 0, shuffle: false)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 15))
                                        Text("Play")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 9)
                                    .background(AppleMusicTheme.accent)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    player.playAll(songs: currentArtist.topSongs, startingAt: 0, shuffle: true)
                                } label: {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 16, weight: .semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(.ultraThinMaterial)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
                .frame(height: 280)
                .clipped()
                
                // Loading Spinner
                if isLoading {
                    ProgressView()
                        .tint(AppleMusicTheme.accent)
                        .padding(.vertical, 30)
                }
                
                // Popular Songs Section
                if !currentArtist.topSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Top Songs")
                        
                        LazyVStack(spacing: 8) {
                            ForEach(Array(currentArtist.topSongs.enumerated()), id: \.element.id) { index, song in
                                SongRow(song: song, isCurrentPlaying: player.currentSong?.id == song.id) {
                                    player.playAll(songs: currentArtist.topSongs, startingAt: index, shuffle: false)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                
                // Albums Section
                if !currentArtist.albums.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Albums")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(currentArtist.albums) { album in
                                    NavigationLink {
                                        AlbumV(album: album)
                                    } label: {
                                        AlbumCard(album: album) {
                                            // NavigationLink handles navigation
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                if currentArtist.topSongs.isEmpty && currentArtist.albums.isEmpty && !isLoading {
                    ContentUnavailableView {
                        Label("No Content Available", systemImage: "music.mic")
                    } description: {
                        Text("No tracks or albums found for this artist.")
                    }
                    .padding(.top, 20)
                }
                
                Spacer(minLength: 100) // Padding for CompactPlayer
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if currentArtist.topSongs.isEmpty {
                isLoading = true
                if let fetched = await BrowseService.shared.fetchArtist(id: artist.id) {
                    currentArtist = fetched
                }
                isLoading = false
            }
        }
    }
    
    private var heroPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.4)
            Image(systemName: "person.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
