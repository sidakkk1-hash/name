import SwiftUI

// MARK: - ExploreV (Listen Now / Home Screen)
/// Modern Apple Music "Listen Now" screen.
/// Features a profile icon header, large title, multiple horizontal carousels (Recently Played, Made for You, Top Picks, Albums, Artists),
/// powered by real YouTube Music Charts and Explore endpoints.
public struct ExploreV: View {
    @Bindable public var player: PlayerEngine = .shared
    @State private var exploreContent: ExploreService.ExploreContent = ExploreService.ExploreContent()
    @State private var isLoading: Bool = true
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Profile avatar row
                    HStack {
                        Spacer()
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 26))
                            .foregroundStyle(AppleMusicTheme.accent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, -10)
                    
                    // 1. Top Picks / Featured Horizontal Carousel
                    if !exploreContent.featuredPlaylists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Top Picks", subtitle: "Featured For You")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(exploreContent.featuredPlaylists) { playlist in
                                        NavigationLink {
                                            PlaylistDetailV(playlist: playlist)
                                        } label: {
                                            MediaCard(
                                                title: playlist.title,
                                                subtitle: playlist.descriptionText ?? "Playlist",
                                                artworkURL: playlist.artworkURL,
                                                cardSize: 200
                                            ) {
                                                // NavigationLink handles tap
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 2. Recently Played (from real user playback history)
                    let history = LibraryRepository.shared.history
                    if !history.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Recently Played")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(history) { song in
                                        MediaCard(
                                            title: song.title,
                                            subtitle: song.artistName,
                                            artworkURL: song.artworkURL,
                                            cardSize: 150
                                        ) {
                                            player.play(song: song)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 3. New Releases / Albums
                    if !exploreContent.newAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "New Releases", subtitle: "Albums")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(exploreContent.newAlbums) { album in
                                        NavigationLink {
                                            AlbumV(album: album)
                                        } label: {
                                            AlbumCard(album: album, size: 160) {
                                                // Handled by NavigationLink
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 4. Favorite Artists
                    if !exploreContent.topArtists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Top Artists", subtitle: "Charts")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 18) {
                                    ForEach(exploreContent.topArtists) { artist in
                                        NavigationLink {
                                            ArtistV(artist: artist)
                                        } label: {
                                            ArtistCard(artist: artist, diameter: 130) {
                                                // Handled by NavigationLink
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 5. Popular Songs (Real Chart Toppers)
                    if !exploreContent.topSongs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Popular Songs", subtitle: "Chart Toppers")
                            
                            LazyVStack(spacing: 8) {
                                ForEach(exploreContent.topSongs.prefix(8)) { song in
                                    SongRow(
                                        song: song,
                                        isCurrentPlaying: player.currentSong?.id == song.id
                                    ) {
                                        player.play(song: song)
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    } else if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(AppleMusicTheme.accent)
                                .padding(.top, 40)
                            Spacer()
                        }
                    }
                }
                .padding(.bottom, 90) // Generous space for CompactPlayer
            }
            .navigationTitle("Listen Now")
            .task {
                let content = await ExploreService.shared.fetchExploreContent()
                self.exploreContent = content
                self.isLoading = false
            }
            .refreshable {
                let content = await ExploreService.shared.fetchExploreContent()
                self.exploreContent = content
            }
        }
    }
}
