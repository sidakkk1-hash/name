import SwiftUI

// MARK: - SettingsV (Apple Music Settings Screen)
/// Reconstructed Settings view with iOS 18 native grouped list styling, playback options, and theme controls.
public struct SettingsV: View {
    @Bindable public var mainTVM: MainTVM = .shared
    @State private var audioQuality: String = "Lossless (24-bit/48kHz)"
    @State private var dolbyAtmos: Bool = true
    @State private var soundCheck: Bool = true
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Audio & Playback Section
                Section("Audio & Playback") {
                    Toggle("Show Song Durations", isOn: $mainTVM.options.showSongDurations)
                    Toggle("Show Rewind Button", isOn: $mainTVM.options.showRewindButton)
                    Toggle("Autoplay Similar Music", isOn: $mainTVM.options.autoplay)
                    Toggle("Dolby Atmos", isOn: $dolbyAtmos)
                    Toggle("Sound Check", isOn: $soundCheck)
                    
                    HStack {
                        Text("Audio Quality")
                        Spacer()
                        Text(audioQuality)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 14))
                    }
                }
                
                // Now Playing Background
                Section("Now Playing Appearance") {
                    Picker("Player Background", selection: $mainTVM.options.playerBackground) {
                        Text("Artwork Blur (Apple Music)").tag(PlayerBackground.default)
                        Text("Solid Accent").tag(PlayerBackground.oneColor)
                        Text("Two-Color Gradient").tag(PlayerBackground.twoColor)
                    }
                }
                
                // Storage & Cache
                Section("Storage") {
                    Button(role: .destructive) {
                        // Clear Cache
                    } label: {
                        Text("Clear Artwork Cache")
                    }
                }
                
                // About Demus
                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Demus (Apple Music Redesign)")
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.22")
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    }
                    HStack {
                        Text("Target")
                        Spacer()
                        Text("iOS 18+ (SwiftUI)")
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 70) // Padding for CompactPlayer
            }
        }
    }
}
