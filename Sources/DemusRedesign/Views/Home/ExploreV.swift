import SwiftUI

// MARK: - ExploreV (Listen Now / Home Screen)
/// Modern Apple Music "Listen Now" screen.
/// Features a profile icon header, large title, multiple horizontal carousels (Recently Played, Made for You, Top Picks, Albums, Artists),
/// and squircle cards with subtle press scale animations.
public struct ExploreV: View {
    @Bindable public var player: PlayerEngine = .shared
    
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
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Top Picks", subtitle: "Featured For You")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(MockData.samplePlaylists) { playlist in
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
                    
                    // 2. Recently Played
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Recently Played")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(MockData.sampleSongs) { song in
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
                    
                    // 3. New Releases / Albums
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "New Releases", subtitle: "Albums")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(MockData.sampleAlbums) { album in
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
                    
                    // 4. Favorite Artists
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Favorite Artists")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 18) {
                                ForEach(MockData.sampleArtists) { artist in
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
                    
                    // 5. Quick Play Popular Songs
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Popular Songs", subtitle: "Chart Toppers")
                        
                        LazyVStack(spacing: 8) {
                            ForEach(MockData.sampleSongs.prefix(4)) { song in
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
                }
                .padding(.bottom, 90) // Generous space for CompactPlayer
            }
            .navigationTitle("Listen Now")
        }
    }
}
