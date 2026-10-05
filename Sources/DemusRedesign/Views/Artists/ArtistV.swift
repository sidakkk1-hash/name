import SwiftUI

// MARK: - ArtistV (Apple Music Artist Detail View)
/// Displays an artist with hero banner, name overlay, Play button, Popular tracks, and Discography / Albums carousel.
public struct ArtistV: View {
    public let artist: Artist
    @Bindable public var player: PlayerEngine = .shared
    
    public init(artist: Artist) {
        self.artist = artist
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large Hero Artist Banner
                ZStack(alignment: .bottomLeading) {
                    if let url = artist.artworkURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                heroPlaceholder
                            @unknown default:
                                heroPlaceholder
                            }
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
                        Text(artist.name)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 12) {
                            Button {
                                if let first = artist.topSongs.first {
                                    player.play(song: first)
                                }
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
                                if let randomSong = artist.topSongs.randomElement() {
                                    player.isShuffle = true
                                    player.play(song: randomSong)
                                }
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
                    .padding(20)
                }
                .frame(height: 280)
                .clipped()
                
                // Popular Songs Section
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Top Songs")
                    
                    LazyVStack(spacing: 8) {
                        ForEach(artist.topSongs) { song in
                            SongRow(song: song, isCurrentPlaying: player.currentSong?.id == song.id) {
                                player.play(song: song)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                // Albums Section
                if !artist.albums.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Albums")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(artist.albums) { album in
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
                
                Spacer(minLength: 100) // Padding for CompactPlayer
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
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
