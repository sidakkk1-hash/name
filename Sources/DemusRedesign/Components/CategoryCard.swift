import SwiftUI

// MARK: - CategoryCard
/// Modern Apple Music search browse category card with vibrant dual-tone gradients.
public struct CategoryCard: View {
    public let category: MusicCategory
    public var onSelect: () -> Void
    
    public init(category: MusicCategory, onSelect: @escaping () -> Void) {
        self.category = category
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button {
            onSelect()
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Vibrant Gradient Surface
                LinearGradient(
                    colors: category.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Translucent Background Icon
                HStack {
                    Spacer()
                    Image(systemName: category.iconName)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.20))
                        .rotationEffect(.degrees(-10))
                        .offset(x: 10, y: 15)
                }
                
                // Category Title
                Text(category.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(14)
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusCard, style: .continuous))
            .shadow(color: category.gradientColors.first?.opacity(0.3) ?? Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.appleMusicCard)
    }
}
