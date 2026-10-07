import SwiftUI

// MARK: - FeaturedPlaylistCard
/// Editorial Apple Music hero card for Featured Playlists on the "Listen Now" tab.
/// Displays an uppercase eyebrow category tag, bold title, descriptive strapline,
/// and large squircle artwork with deep ambient shadow.
public struct FeaturedPlaylistCard: View {
    public let playlist: Playlist
    public var cardWidth: CGFloat = 220.0
    
    public init(playlist: Playlist, cardWidth: CGFloat = 220.0) {
        self.playlist = playlist
        self.cardWidth = cardWidth
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Eyebrow and Headline
            VStack(alignment: .leading, spacing: 3) {
                Text("FEATURED PLAYLIST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppleMusicTheme.accent)
                    .tracking(0.6)
                
                Text(playlist.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppleMusicTheme.label)
                    .lineLimit(1)
                
                if let desc = playlist.descriptionText, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        .lineLimit(1)
                }
            }
            .frame(width: cardWidth, alignment: .leading)
            
            // Large Squircle Artwork
            ZStack {
                if let rawUrl = playlist.artworkURL, let url = ImageHelper.highResArtworkURL(from: rawUrl, resolution: .card) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderImage
                    }
                } else {
                    placeholderImage
                }
            }
            .frame(width: cardWidth, height: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusLargeCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppleMusicTheme.radiusLargeCard, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 5)
        }
        .frame(width: cardWidth)
        .contentShape(Rectangle())
    }
    
    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note.list")
                .font(.system(size: cardWidth * 0.28))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
