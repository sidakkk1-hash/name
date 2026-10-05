import SwiftUI

// MARK: - ArtistCard
/// Apple Music circular artist portrait card.
public struct ArtistCard: View {
    public let artist: Artist
    public var diameter: CGFloat = 135.0
    public var onSelect: () -> Void
    
    public init(artist: Artist, diameter: CGFloat = 135.0, onSelect: @escaping () -> Void) {
        self.artist = artist
        self.diameter = diameter
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    if let rawUrl = artist.artworkURL, let url = ImageHelper.highResArtworkURL(from: rawUrl, resolution: .card) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            artistPlaceholder
                        }
                    } else {
                        artistPlaceholder
                    }
                }
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                
                VStack(spacing: 2) {
                    Text(artist.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppleMusicTheme.label)
                        .lineLimit(1)
                    
                    Text(artist.subscribers ?? "Artist")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        .lineLimit(1)
                }
                .frame(width: diameter)
            }
        }
        .buttonStyle(.appleMusicCard)
    }
    
    private var artistPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: diameter * 0.35))
                .foregroundStyle(.secondary)
        }
    }
}
