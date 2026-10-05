import SwiftUI

// MARK: - DynamicPlayerBackground
/// Creates a live, artwork-driven ambient background matching modern Apple Music.
/// Combines heavy blurs, fluid breathing motion, satin frosted material,
/// and deep gradient overlays to guarantee high-contrast readability.
public struct DynamicPlayerBackground: View {
    public let artworkURL: URL?
    public var blurRadius: CGFloat = 65.0
    public var darkOverlayOpacity: Double = 0.45
    
    @State private var isBreathing: Bool = false
    
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
                
                // Living Blurred Artwork Mesh Layer
                if let url = ImageHelper.highResArtworkURL(from: artworkURL, resolution: .card) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: proxy.size.width * 1.35, height: proxy.size.height * 1.35)
                            .clipped()
                            .blur(radius: blurRadius, opaque: true)
                            .saturation(1.3) // Vibrant Apple Music color pop
                            .scaleEffect(isBreathing ? 1.08 : 1.0)
                            .rotationEffect(.degrees(isBreathing ? 3 : -3))
                            .animation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true), value: isBreathing)
                    } placeholder: {
                        fallbackGradient
                    }
                    .id(url.absoluteString)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.4), value: url)
                } else {
                    fallbackGradient
                        .transition(.opacity)
                }
                
                // Frosted Liquid Glass Satin Veil
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.35))
                
                // Apple Music Signature Dynamic Gradient Overlays
                // 1. Top subtle vignette for status bar / grabber
                LinearGradient(
                    colors: [Color.black.opacity(0.40), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                
                // 2. Bottom deep gradient for maximum readability of white playback controls & scrubber
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.20),
                        .init(color: Color.black.opacity(0.35), location: 0.55),
                        .init(color: Color.black.opacity(0.80), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            isBreathing = true
        }
    }
    
    private var fallbackGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 35 / 255.0, green: 20 / 255.0, blue: 45 / 255.0),
                Color(red: 18 / 255.0, green: 15 / 255.0, blue: 28 / 255.0),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
