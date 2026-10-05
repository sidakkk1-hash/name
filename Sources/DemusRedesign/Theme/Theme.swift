import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Apple Music Native Design Tokens & Design System
public enum AppleMusicTheme {
    // Primary Apple Music Red/Pink Accent (#FA243C)
    public static let accent = Color(red: 250 / 255.0, green: 36 / 255.0, blue: 60 / 255.0)
    
    // Gradients
    public static let accentGradient = LinearGradient(
        colors: [
            Color(red: 255 / 255.0, green: 45 / 255.0, blue: 85 / 255.0),
            Color(red: 250 / 255.0, green: 36 / 255.0, blue: 60 / 255.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Backgrounds & Surface Colors
    #if canImport(UIKit)
    public static let systemBackground = Color(uiColor: .systemBackground)
    public static let secondarySystemBackground = Color(uiColor: .secondarySystemBackground)
    public static let tertiarySystemBackground = Color(uiColor: .tertiarySystemBackground)
    public static let systemGroupedBackground = Color(uiColor: .systemGroupedBackground)
    public static let secondarySystemGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
    
    // Text Hierarchy
    public static let label = Color(uiColor: .label)
    public static let secondaryLabel = Color(uiColor: .secondaryLabel)
    public static let tertiaryLabel = Color(uiColor: .tertiaryLabel)
    public static let quaternaryLabel = Color(uiColor: .quaternaryLabel)
    public static let separator = Color(uiColor: .separator)
    #else
    public static let systemBackground = Color.black
    public static let secondarySystemBackground = Color.gray.opacity(0.15)
    public static let tertiarySystemBackground = Color.gray.opacity(0.1)
    public static let systemGroupedBackground = Color.black
    public static let secondarySystemGroupedBackground = Color.gray.opacity(0.15)
    public static let label = Color.primary
    public static let secondaryLabel = Color.secondary
    public static let tertiaryLabel = Color.secondary.opacity(0.7)
    public static let quaternaryLabel = Color.secondary.opacity(0.4)
    public static let separator = Color.gray.opacity(0.3)
    #endif
    
    public static let subtleBorder = Color.primary.opacity(0.08)
    
    // Corner Radii (Apple Continuous Squircle)
    public static let radiusThumbnail: CGFloat = 8.0
    public static let radiusCard: CGFloat = 12.0
    public static let radiusLargeCard: CGFloat = 16.0
    public static let radiusMiniPlayer: CGFloat = 14.0
    public static let radiusArtworkNowPlaying: CGFloat = 16.0
    public static let radiusCapsule: CGFloat = 999.0
    
    // Spacing Constants
    public static let spacingXS: CGFloat = 4.0
    public static let spacingS: CGFloat = 8.0
    public static let spacingM: CGFloat = 12.0
    public static let spacingL: CGFloat = 16.0
    public static let spacingXL: CGFloat = 20.0
    public static let spacingXXL: CGFloat = 28.0
    
    // Component Dimensions
    public static let miniPlayerHeight: CGFloat = 64.0
    public static let miniPlayerHorizontalPadding: CGFloat = 12.0
    public static let miniPlayerArtworkSize: CGFloat = 44.0
    public static let songRowArtworkSize: CGFloat = 52.0
    
    // Shadows
    public static let ambientShadow = Shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
    public static let artworkShadow = Shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 12)
    public static let miniPlayerShadow = Shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
    
    // Motion / Animations
    public static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.82)
    public static let smoothCrossfade = Animation.easeInOut(duration: 0.45)
    public static let quickTransition = Animation.easeInOut(duration: 0.22)
    
    public struct Shadow: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }
}

// MARK: - Interactive Button Press Animation Style
public struct AppleMusicScaleButtonStyle: ButtonStyle {
    public var pressedScale: CGFloat = 0.97
    
    public init(pressedScale: CGFloat = 0.97) {
        self.pressedScale = pressedScale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == AppleMusicScaleButtonStyle {
    static var appleMusicCard: AppleMusicScaleButtonStyle {
        AppleMusicScaleButtonStyle(pressedScale: 0.97)
    }
    
    static var appleMusicPlayButton: AppleMusicScaleButtonStyle {
        AppleMusicScaleButtonStyle(pressedScale: 0.92)
    }
}

// MARK: - Squircle Continuous Corner View Modifier
public struct ContinuousCornerModifier: ViewModifier {
    public var radius: CGFloat
    
    public func body(content: Content) -> some View {
        content.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

public extension View {
    func continuousCorner(_ radius: CGFloat) -> some View {
        modifier(ContinuousCornerModifier(radius: radius))
    }
}
