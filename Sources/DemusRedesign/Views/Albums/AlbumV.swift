import SwiftUI

// MARK: - AlbumV (Apple Music Album Detail View)
/// Displays an album with large hero artwork, release metadata, Play and Shuffle action buttons, and full tracklist.
public struct AlbumV: View {
    public let album: Album
    @Bindable public var player: PlayerEngine = .shared
    
    public init(album: Album) {
        self.album = album
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large Centered Artwork
                ZStack {
                    if let url = album.artworkURL {
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
                .frame(width: 240, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusLargeCard, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppleMusicTheme.radiusLargeCard, style: .continuous)
                        .stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.20), radius: 18, x: 0, y: 10)
                .padding(.top, 12)
                
                // Album Title & Metadata
                VStack(spacing: 4) {
                    Text(album.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppleMusicTheme.label)
                        .multilineTextAlignment(.center)
                    
                    Text(album.artist)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(AppleMusicTheme.accent)
                    
                    if let release = album.releaseDate {
                        Text("Pop · \(release)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    }
                }
                .padding(.horizontal, 20)
                
                // Action Buttons (Play & Shuffle)
                HStack(spacing: 16) {
                    Button {
                        if let first = album.songs.first {
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
                        if let randomSong = album.songs.randomElement() {
                            player.isShuffle = true
                            player.play(song: randomSong)
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
                LazyVStack(spacing: 0) {
                    ForEach(Array(album.songs.enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: 16) {
                            Text("\(index + 1)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                .frame(width: 24, alignment: .trailing)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(player.currentSong?.id == song.id ? AppleMusicTheme.accent : AppleMusicTheme.label)
                                    .lineLimit(1)
                                
                                Text(song.artistName)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button {
                                // Options
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.play(song: song)
                        }
                        
                        Divider()
                            .padding(.leading, 60)
                    }
                }
                
                // Album Footer Copyright & Details
                VStack(spacing: 6) {
                    Text("\(album.songs.count) Songs, 18 Minutes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    
                    Text("℗ 2026 Republic Records, a division of UMG Recordings, Inc.")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AppleMusicTheme.tertiaryLabel)
                }
                .padding(.top, 16)
                .padding(.bottom, 100) // Padding for CompactPlayer
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var placeholderImage: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Image(systemName: "opticaldisc")
                .font(.system(size: 70))
                .foregroundStyle(.secondary)
        }
    }
}
