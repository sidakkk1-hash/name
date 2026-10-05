import SwiftUI

// MARK: - SongLyricsV (Immersive Time-Synced Style Lyrics View)
/// Apple Music-style full-screen immersive lyrics view.
/// Employs DynamicPlayerBackground, fluid large-typography lyric lines with opacity hierarchy,
/// powered by real time-synchronized lyrics from lrclib.net.
public struct SongLyricsV: View {
    @Bindable public var player: PlayerEngine
    @Environment(\.dismiss) private var dismiss
    
    @State private var lyricLines: [LyricsService.LyricLine] = []
    @State private var isLoading: Bool = true
    
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
                if lyricLines.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                            Text("Loading Lyrics...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("No Lyrics Available")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 32) {
                                ForEach(Array(lyricLines.enumerated()), id: \.element.id) { index, line in
                                    let isActive = isLineActive(lineTime: line.time, index: index)
                                    
                                    Button {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                            player.seek(to: line.time)
                                            proxy.scrollTo(line.id, anchor: .center)
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
                                    .id(line.id)
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 40)
                        }
                        .onChange(of: player.currentTime) { _, newTime in
                            if let activeIndex = lyricLines.lastIndex(where: { $0.time <= newTime }) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(lyricLines[activeIndex].id, anchor: .center)
                                }
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
        .task {
            guard let song = player.currentSong else { return }
            self.isLoading = true
            let lines = await LyricsService.shared.fetchLyrics(
                trackName: song.title,
                artistName: song.artistName,
                duration: Int(song.duration),
                videoId: song.id
            )
            self.lyricLines = lines
            self.isLoading = false
        }
    }
    
    private func isLineActive(lineTime: TimeInterval, index: Int) -> Bool {
        if index < lyricLines.count - 1 {
            let nextTime = lyricLines[index + 1].time
            return player.currentTime >= lineTime && player.currentTime < nextTime
        }
        return player.currentTime >= lineTime
    }
}
