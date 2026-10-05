import SwiftUI

// MARK: - AlbumCard
/// Apple Music album presentation card with high-resolution artwork and metadata.
public struct AlbumCard: View {
    public let album: Album
    public var size: CGFloat = 160.0
    public var onSelect: (() -> Void)?
    
    public init(album: Album, size: CGFloat = 160.0, onSelect: (() -> Void)? = nil) {
        self.album = album
        self.size = size
        self.onSelect = onSelect
    }
    
    public var body: some View {
        if let onSelect = onSelect {
            Button {
                onSelect()
            } label: {
                cardContent
            }
            .buttonStyle(.appleMusicCard)
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let rawUrl = album.artworkURL, let url = ImageHelper.highResArtworkURL(from: rawUrl, resolution: .card) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        albumPlaceholder
                    }
                } else {
                    albumPlaceholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppleMusicTheme.radiusCard, style: .continuous)
                    .stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppleMusicTheme.label)
                    .lineLimit(1)
                
                Text(albumSubtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    .lineLimit(1)
            }
            .frame(width: size, alignment: .leading)
        }
        .frame(width: size)
        .contentShape(Rectangle())
    }
    
    private var albumSubtitle: String {
        var parts: [String] = []
        if !album.artist.isEmpty {
            parts.append(album.artist)
        }
        if let y = album.year ?? album.releaseDate, !y.isEmpty {
            parts.append(y)
        }
        return parts.joined(separator: " • ")
    }
    
    private var albumPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "opticaldisc")
                .font(.system(size: size * 0.3))
                .foregroundStyle(.secondary)
        }
    }
}
