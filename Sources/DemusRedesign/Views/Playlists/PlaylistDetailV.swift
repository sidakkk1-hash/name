import SwiftUI

// MARK: - PlaylistDetailV (Apple Music Playlist Detail View)
/// Displays a playlist with header artwork, description, Play/Shuffle actions, and tracks.
public struct PlaylistDetailV: View {
    public let playlist: Playlist
    @Bindable public var player: PlayerEngine = .shared
    
    public init(playlist: Playlist) {
        self.playlist = playlist
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Artwork
                ZStack {
                    if let url = playlist.artworkURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                placeholderImage
                            @unknown default:
                                placeholderImage
                            }
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
                    Text(playlist.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppleMusicTheme.label)
                        .multilineTextAlignment(.center)
                    
                    if let desc = playlist.descriptionText {
                        Text(desc)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                
                // Play & Shuffle Action Buttons
                HStack(spacing: 16) {
                    Button {
                        if let first = playlist.songs.first {
                            player.play(song: first)
                        }
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
                        if let random = playlist.songs.randomElement() {
                            player.isShuffle = true
                            player.play(song: random)
                        }
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
                
                // Track List
                LazyVStack(spacing: 8) {
                    ForEach(playlist.songs) { song in
                        SongRow(
                            song: song,
                            isCurrentPlaying: player.currentSong?.id == song.id
                        ) {
                            player.play(song: song)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                
                Spacer(minLength: 100) // Padding for CompactPlayer
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
