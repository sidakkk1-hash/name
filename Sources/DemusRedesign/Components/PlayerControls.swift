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

#if canImport(MediaPlayer)
import MediaPlayer

// MARK: - NativeSystemVolumeView
/// Native MPVolumeView wrapped in UIViewRepresentable.
/// Keeps on-screen slider synchronized 1:1 with hardware volume buttons,
/// AirPods volume, and Control Center without using private APIs.
public struct NativeSystemVolumeView: UIViewRepresentable {
    public init() {}
    
    public func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false // Route picker is managed separately
        volumeView.showsVolumeSlider = true
        
        // Style inner slider to match Apple Music dark frosted glass theme
        DispatchQueue.main.async {
            for subview in volumeView.subviews {
                if let slider = subview as? UISlider {
                    slider.minimumTrackTintColor = UIColor.white.withAlphaComponent(0.85)
                    slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.20)
                    slider.thumbTintColor = UIColor.white
                }
            }
        }
        return volumeView
    }
    
    public func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
#endif

// MARK: - AppleMusicVolumeSlider
/// Modern iOS 17/18 Apple Music volume slider.
/// Features a sleek white capsule track, speaker icons, spring dragging expansion,
/// and direct integration with PlayerEngine volume.
public struct AppleMusicVolumeSlider: View {
    @Bindable public var player: PlayerEngine = .shared
    @State private var isDragging: Bool = false
    @State private var localVolume: Double = 0.8
    
    public init() {
        self._localVolume = State(initialValue: PlayerEngine.shared.volume)
    }
    
    public init(volume: Binding<Double>) {
        self._localVolume = State(initialValue: volume.wrappedValue)
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.60))
            
            GeometryReader { geo in
                let width = geo.size.width
                let height: CGFloat = isDragging ? 9.0 : 6.0
                let currentFraction = max(0.0, min(1.0, isDragging ? localVolume : player.volume))
                
                ZStack(alignment: .leading) {
                    // Track Background (Frosted translucent)
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: height)
                    
                    // Filled Track (White Apple Music liquid bar)
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: max(height, width * CGFloat(currentFraction)), height: height)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            let progress = max(0.0, min(1.0, Double(gesture.location.x / width)))
                            localVolume = progress
                            player.volume = progress
                        }
                        .onEnded { _ in
                            isDragging = false
                            player.volume = localVolume
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        }
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isDragging)
            }
            .frame(height: 28)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.60))
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
