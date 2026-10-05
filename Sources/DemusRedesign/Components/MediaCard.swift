import SwiftUI

// MARK: - MediaCard
/// Apple Music square artwork card for carousels (Featured, Made for You, Recently Played).
public struct MediaCard: View {
    public let title: String
    public let subtitle: String
    public let artworkURL: URL?
    public var cardSize: CGFloat = 164.0
    public var onSelect: () -> Void
    
    public init(
        title: String,
        subtitle: String,
        artworkURL: URL?,
        cardSize: CGFloat = 164.0,
        onSelect: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.cardSize = cardSize
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                // Square Artwork
                ZStack {
                    if let url = artworkURL {
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
                .frame(width: cardSize, height: cardSize)
                .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusCard, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppleMusicTheme.radiusCard, style: .continuous)
                        .stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
                
                // Card Titles
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppleMusicTheme.label)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        .lineLimit(1)
                }
                .frame(width: cardSize, alignment: .leading)
            }
        }
        .buttonStyle(.appleMusicCard)
    }
    
    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: cardSize * 0.28))
                .foregroundStyle(.secondary)
        }
    }
}
