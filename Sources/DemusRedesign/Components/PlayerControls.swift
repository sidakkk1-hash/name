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
            
            // Dominant Play / Pause Button with Buffering Protection
            Button {
                player.togglePlay()
            } label: {
                ZStack {
                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.6)
                            .frame(width: 68, height: 68)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 68, height: 68)
                    }
                }
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

#if canImport(MediaPlayer) && canImport(UIKit)
import MediaPlayer
import UIKit

// MARK: - AppleMusicNativeVolumeView
/// Native MPVolumeView synchronized 1:1 with hardware iPhone volume buttons,
/// AirPods volume, and Control Center. Overrides layoutSubviews to ensure
/// track is pure white and NEVER defaults to system blue.
public final class AppleMusicNativeVolumeView: MPVolumeView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        showsRouteButton = false
        showsVolumeSlider = true
        applyStyling()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        showsRouteButton = false
        showsVolumeSlider = true
        applyStyling()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        applyStyling()
    }
    
    private func applyStyling() {
        for subview in subviews {
            if let slider = subview as? UISlider {
                slider.tintColor = .white
                slider.minimumTrackTintColor = .white
                slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.20)
                slider.thumbTintColor = .white
            }
        }
    }
}

public struct NativeSystemVolumeRepresentable: UIViewRepresentable {
    public init() {}
    
    public func makeUIView(context: Context) -> AppleMusicNativeVolumeView {
        let view = AppleMusicNativeVolumeView(frame: .zero)
        return view
    }
    
    public func updateUIView(_ uiView: AppleMusicNativeVolumeView, context: Context) {}
}
#endif

// MARK: - AppleMusicVolumeSlider
/// Apple Music signature hardware-synced volume slider matching iOS Music.
public struct AppleMusicVolumeSlider: View {
    public init() {}
    public init(volume: Binding<Double>) {}
    
    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            
            #if canImport(MediaPlayer) && canImport(UIKit)
            NativeSystemVolumeRepresentable()
                .frame(height: 32)
            #else
            Slider(value: .constant(0.8), in: 0...1)
                .tint(.white)
            #endif
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

#if canImport(AVKit)
import AVKit

// MARK: - AirPlayRoutePickerView
public struct AirPlayRoutePickerView: UIViewRepresentable {
    public init() {}
    
    public func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor.white.withAlphaComponent(0.85)
        picker.activeTintColor = UIColor(AppleMusicTheme.accent)
        picker.prioritizesVideoDevices = false
        picker.backgroundColor = .clear
        return picker
    }
    
    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#endif

// MARK: - AppleMusicSecondaryToolbar
/// Bottom auxiliary toolbar: Lyrics, AirPlay / Bluetooth, Queue with frosted glass circular capsules.
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
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                mainTVM.isLyricsPresented = true
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.appleMusicPlayButton)
            
            Spacer()
            
            // AirPlay & Bluetooth Device Picker Button
            #if canImport(AVKit)
            AirPlayRoutePickerView()
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
            #else
            Image(systemName: "airplayaudio")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
            #endif
            
            Spacer()
            
            // Queue / Playing Next Button
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                mainTVM.isQueuePresented = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.appleMusicPlayButton)
        }
    }
}
