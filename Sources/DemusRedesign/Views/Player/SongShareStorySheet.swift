import SwiftUI

// MARK: - SongShareStorySheet (Instagram & Social Share Card)
/// Renders a beautiful frosted glass card with artwork, title, artist, and Demus branding
/// suitable for sharing to Instagram Stories or saving as an image.
public struct SongShareStorySheet: View {
    public let song: Song
    @Environment(\.dismiss) private var dismiss
    
    public init(song: Song) {
        self.song = song
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // The Share Card Canvas
                VStack(spacing: 18) {
                    // Artwork
                    ZStack {
                        if let url = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id, resolution: .full) {
                            CachedAsyncImage(url: url) { img in
                                img
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 10)
                    
                    // Song Info
                    VStack(spacing: 6) {
                        Text(song.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Text(song.artistName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    
                    // Branding Pill
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.98, green: 0.15, blue: 0.28))
                        Text("Velora Music")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
                .padding(28)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.65))
                        
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    }
                )
                .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
                
                Spacer()
                
                // Share Action Button
                ShareLink(item: "\(song.title) by \(song.artistName) on Demus Music") {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Share Story Card")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(red: 0.98, green: 0.15, blue: 0.28))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}
