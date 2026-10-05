import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - VisualEffectView (UIVisualEffectView SwiftUI Bridge)
#if canImport(UIKit)
public struct VisualEffectView: UIViewRepresentable {
    public var style: UIBlurEffect.Style
    
    public init(style: UIBlurEffect.Style = .systemUltraThinMaterial) {
        self.style = style
    }
    
    public func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
#endif

// MARK: - SongThumbnailV (Row thumbnail matching Demus metadata)
public struct SongThumbnailV: View {
    public let song: Song
    public var size: CGFloat = 52
    
    public init(song: Song, size: CGFloat = 52) {
        self.song = song
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            if let url = song.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        fallbackPlaceholder
                    @unknown default:
                        fallbackPlaceholder
                    }
                }
            } else {
                fallbackPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusThumbnail, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppleMusicTheme.radiusThumbnail, style: .continuous)
                .stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
    }
    
    private var fallbackPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.35))
                .foregroundStyle(.secondary)
        }
    }
}
