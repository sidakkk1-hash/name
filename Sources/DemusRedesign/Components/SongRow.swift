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
                    if let url = song.artworkURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img
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
                Button {
                    onMenu?()
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
