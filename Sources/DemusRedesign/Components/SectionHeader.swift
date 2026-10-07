import SwiftUI

// MARK: - SectionHeader
/// Apple Music standard section header with large bold title, optional subtitle, and "See All" button.
public struct SectionHeader: View {
    public let title: String
    public var subtitle: String?
    public var onSeeAll: (() -> Void)?
    
    public init(title: String, subtitle: String? = nil, onSeeAll: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.onSeeAll = onSeeAll
    }
    
    public var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle = subtitle {
                    let cleanSub = subtitle.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanSub.count > 1 && cleanSub.uppercased() != "BECAUSE YOU RECENTLY LISTENED TO" {
                        Text(cleanSub.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .kerning(0.5)
                    }
                }
                
                let cleanTitle = title.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                Text(cleanTitle.isEmpty || cleanTitle == "More From" ? "More Music" : cleanTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppleMusicTheme.label)
            }
            
            Spacer()
            
            if let onSeeAll = onSeeAll {
                Button {
                    onSeeAll()
                } label: {
                    HStack(spacing: 2) {
                        Text("See All")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppleMusicTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
