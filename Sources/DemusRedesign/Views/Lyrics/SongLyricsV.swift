import SwiftUI

// MARK: - SongLyricsV (Immersive Time-Synced Style Lyrics View)
/// Apple Music-style full-screen immersive lyrics view.
/// Employs DynamicPlayerBackground, fluid large-typography lyric lines with opacity hierarchy,
/// and smooth interactive scrolling.
public struct SongLyricsV: View {
    @Bindable public var player: PlayerEngine
    @Environment(\.dismiss) private var dismiss
    
    // Sample synchronized lyric lines for demonstration
    @State private var sampleLyrics: [(time: TimeInterval, text: String)] = [
        (0.0, "Yeah"),
        (4.0, "I've been tryna call"),
        (8.0, "I've been on my own for long enough"),
        (14.0, "Maybe you can show me how to love, maybe"),
        (22.0, "I'm going through withdrawals"),
        (28.0, "You don't even have to do too much"),
        (34.0, "You can turn me on with just a touch, baby"),
        (42.0, "I look around and Sin City's cold and empty"),
        (50.0, "No one's around to judge me"),
        (56.0, "I can't see clearly when you're gone"),
        (64.0, "I said, ooh, I'm blinded by the lights"),
        (72.0, "No, I can't sleep until I feel your touch"),
        (80.0, "I said, ooh, I'm drowning in the night"),
        (88.0, "Oh, when I'm like this, you're the one I trust"),
        (96.0, "Hey, hey, hey")
    ]
    
    public init(player: PlayerEngine = .shared) {
        self.player = player
    }
    
    public var body: some View {
        ZStack {
            // Dynamic Blurred Artwork Background
            DynamicPlayerBackground(
                artworkURL: player.currentSong?.artworkURL,
                blurRadius: 70,
                darkOverlayOpacity: 0.55
            )
            
            VStack(spacing: 0) {
                // Header Bar with Dismiss Button and Current Song info
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentSong?.title ?? "Lyrics")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(player.currentSong?.artistName ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
                
                // Scrolling Lyrics Body
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 32) {
                            ForEach(Array(sampleLyrics.enumerated()), id: \.offset) { index, line in
                                let isActive = isLineActive(lineTime: line.time, index: index)
                                
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        player.seek(to: line.time)
                                        proxy.scrollTo(index, anchor: .center)
                                    }
                                } label: {
                                    Text(line.text)
                                        .font(.system(size: isActive ? 32 : 26, weight: isActive ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(.white)
                                        .opacity(isActive ? 1.0 : 0.35)
                                        .blur(radius: isActive ? 0 : 0.3)
                                        .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                        .multilineTextAlignment(.leading)
                                        .animation(.easeInOut(duration: 0.3), value: isActive)
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 40)
                    }
                    .onChange(of: player.currentTime) { _, newTime in
                        if let activeIndex = sampleLyrics.lastIndex(where: { $0.time <= newTime }) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(activeIndex, anchor: .center)
                            }
                        }
                    }
                }
                
                // Bottom Mini Playback Scrubber for convenience while reading lyrics
                VStack(spacing: 8) {
                    AppleMusicScrubber(player: player)
                        .padding(.horizontal, 28)
                    
                    HStack(spacing: 40) {
                        Button {
                            player.prev()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        }
                        
                        Button {
                            player.togglePlay()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                        
                        Button {
                            player.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private func isLineActive(lineTime: TimeInterval, index: Int) -> Bool {
        if index < sampleLyrics.count - 1 {
            let nextTime = sampleLyrics[index + 1].time
            return player.currentTime >= lineTime && player.currentTime < nextTime
        }
        return player.currentTime >= lineTime
    }
}
