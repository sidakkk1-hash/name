import SwiftUI

// MARK: - AppleMusicScrubber
/// Authentic thin Apple Music scrubber with interactive smooth dragging and elapsed/remaining indicators.
public struct AppleMusicScrubber: View {
    @Bindable public var player: PlayerEngine
    @State private var isDragging: Bool = false
    @State private var dragLocationProgress: Double = 0.0
    
    public init(player: PlayerEngine) {
        self.player = player
    }
    
    private var currentProgress: Double {
        if isDragging { return dragLocationProgress }
        guard player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }
    
    public var body: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Unfilled Track
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: isDragging ? 6 : 4)
                    
                    // Filled Track
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(
                            width: max(0, min(geo.size.width * currentProgress, geo.size.width)),
                            height: isDragging ? 6 : 4
                        )
                    
                    // Subtle Thumb Knob (appears during touch)
                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                        .frame(width: isDragging ? 16 : 8, height: isDragging ? 16 : 8)
                        .offset(x: max(0, min(geo.size.width * currentProgress - (isDragging ? 8 : 4), geo.size.width - (isDragging ? 16 : 8))))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragLocationProgress = max(0, min(value.location.x / geo.size.width, 1.0))
                        }
                        .onEnded { value in
                            let final = max(0, min(value.location.x / geo.size.width, 1.0))
                            player.seek(to: final * player.duration)
                            isDragging = false
                        }
                )
            }
            .frame(height: 16)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
            
            // Time Labels
            HStack {
                Text(timeFormatted(player.currentTime))
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.65))
                    .monospacedDigit()
                
                Spacer()
                
                Text("-" + timeFormatted(max(0, player.duration - player.currentTime)))
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.65))
                    .monospacedDigit()
            }
        }
    }
    
    private func timeFormatted(_ totalSeconds: TimeInterval) -> String {
        let seconds = Int(totalSeconds) % 60
        let minutes = Int(totalSeconds) / 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AppleMusicPlaybackControls
/// Primary playback toolbar with previous, next, and visually dominant play/pause.
public struct AppleMusicPlaybackControls: View {
    @Bindable public var player: PlayerEngine
    
    public init(player: PlayerEngine) {
        self.player = player
    }
    
    public var body: some View {
        HStack(spacing: 52) {
            // Previous Button
            Button {
                player.prev()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.appleMusicPlayButton)
            
            // Dominant Play / Pause Button
            Button {
                player.togglePlay()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 68, height: 68)
            }
            .buttonStyle(.appleMusicPlayButton)
            
            // Next Button
            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.appleMusicPlayButton)
        }
    }
}

// MARK: - AppleMusicVolumeSlider
/// Native-style volume slider with minimum and maximum speaker SF Symbols.
public struct AppleMusicVolumeSlider: View {
    @Binding public var volume: Double
    
    public init(volume: Binding<Double>) {
        self._volume = volume
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
            
            Slider(value: $volume, in: 0...1)
                .tint(.white.opacity(0.85))
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

// MARK: - AppleMusicSecondaryToolbar
/// Bottom auxiliary toolbar: Lyrics, AirPlay, Queue.
public struct AppleMusicSecondaryToolbar: View {
    @Bindable public var mainTVM: MainTVM
    @Bindable public var player: PlayerEngine
    
    public init(mainTVM: MainTVM, player: PlayerEngine) {
        self.mainTVM = mainTVM
        self.player = player
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Lyrics Button
            Button {
                mainTVM.isLyricsPresented = true
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.appleMusicPlayButton)
            
            Spacer()
            
            // AirPlay Button
            Button {
                // AirPlay route picker action
            } label: {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.appleMusicPlayButton)
            
            Spacer()
            
            // Queue / Playing Next Button
            Button {
                mainTVM.isQueuePresented = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.appleMusicPlayButton)
        }
    }
}
