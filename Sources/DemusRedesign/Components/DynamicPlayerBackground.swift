import SwiftUI

// MARK: - DynamicPlayerBackground
/// Creates a live, artwork-driven ambient background matching modern Apple Music.
/// It uses the current song's artwork, scaled to fill, heavily blurred (45-70pt),
/// overlaid with a dark gradient toward the bottom to guarantee high-contrast readable controls.
/// Automatically crossfades with a 0.45s animation on song change.
public struct DynamicPlayerBackground: View {
    public let artworkURL: URL?
    public var blurRadius: CGFloat = 65.0
    public var darkOverlayOpacity: Double = 0.45
    
    public init(artworkURL: URL?, blurRadius: CGFloat = 65.0, darkOverlayOpacity: Double = 0.45) {
        self.artworkURL = artworkURL
        self.blurRadius = blurRadius
        self.darkOverlayOpacity = darkOverlayOpacity
    }
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Base background color
                Color.black
                
                // Blurred Artwork Layer with smooth crossfade
                if let url = artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: proxy.size.width * 1.25, height: proxy.size.height * 1.25)
                                .clipped()
                                .blur(radius: blurRadius, opaque: true)
                                .saturation(1.25) // Vibrant Apple Music color pop
                                .transition(.opacity.animation(AppleMusicTheme.smoothCrossfade))
                        case .failure, .empty:
                            fallbackGradient
                        @unknown default:
                            fallbackGradient
                        }
                    }
                    .id(url.absoluteString) // Triggers transition when artwork changes
                } else {
                    fallbackGradient
                }
                
                // Apple Music Signature Dynamic Gradient Overlays
                // 1. Top subtle vignette for status bar / grabber
                LinearGradient(
                    colors: [Color.black.opacity(0.35), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                
                // 2. Bottom deep gradient for maximum readability of white playback controls & scrubber
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.25),
                        .init(color: Color.black.opacity(0.35), location: 0.6),
                        .init(color: Color.black.opacity(0.75), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
    
    private var fallbackGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 35 / 255.0, green: 20 / 255.0, blue: 38 / 255.0),
                Color(red: 18 / 255.0, green: 15 / 255.0, blue: 25 / 255.0),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
