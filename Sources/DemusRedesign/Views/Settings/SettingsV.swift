import SwiftUI

// MARK: - SettingsV (Apple Music Settings Screen)
/// Reconstructed Settings view with Google/YouTube account connection,
/// iOS 18 native grouped list styling, playback options, and theme controls.
public struct SettingsV: View {
    @Bindable public var mainTVM: MainTVM = .shared
    @Bindable private var accountManager: GoogleAccountManager = .shared
    @State private var isLoginSheetPresented: Bool = false
    @State private var audioQuality: String = "Lossless (24-bit/48kHz)"
    @State private var dolbyAtmos: Bool = true
    @State private var soundCheck: Bool = true
    
    // Apple 2026 Features Storage
    @AppStorage("demus_song_transitions") private var songTransition: String = "Crossfade"
    @AppStorage("demus_crossfade_enabled") private var isCrossfadeEnabled: Bool = true
    @AppStorage("demus_crossfade_duration") private var crossfadeDuration: Double = 6.0
    @AppStorage("demus_animated_artwork") private var animatedArtworkSetting: String = "Wi-Fi & Cellular"
    @AppStorage("demus_music_haptics_enabled") private var musicHapticsEnabled: Bool = true
    @AppStorage("demus_music_haptics_intensity") private var musicHapticsIntensity: String = "Medium"
    @AppStorage("demus_music_haptics_mode") private var musicHapticsMode: String = "Full Mix"
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // YouTube Music Account Sync Section
                Section("YouTube Music Account") {
                    if accountManager.isLoggedIn {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(AppleMusicTheme.accent)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(accountManager.userEmail ?? "Connected Account")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppleMusicTheme.label)
                                
                                Text("Synced with YouTube Music")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            }
                        }
                        .padding(.vertical, 2)
                        
                        Button(role: .destructive) {
                            accountManager.signOut()
                        } label: {
                            Text("Sign Out")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync Your Music")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppleMusicTheme.label)
                            
                            Text("Sign in with Google to sync your Liked Songs, personal playlists, and recommendations directly into Demus.")
                                .font(.system(size: 13))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            
                            Button {
                                isLoginSheetPresented = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.badge.key.fill")
                                    Text("Sign in with Google")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppleMusicTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 6)
                    }
                }
                
                // Song Transitions Section (Apple Music 2026)
                Section {
                    Picker("Song Transitions", selection: $songTransition) {
                        Text("Off").tag("Off")
                        Text("Crossfade").tag("Crossfade")
                        Text("AutoMix").tag("AutoMix")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: songTransition) { _, val in
                        isCrossfadeEnabled = (val == "Crossfade" || val == "AutoMix")
                    }
                    
                    if songTransition == "Crossfade" {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Crossfade Duration")
                                Spacer()
                                Text("\(Int(crossfadeDuration))s")
                                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Slider(value: $crossfadeDuration, in: 1...12, step: 1)
                                .tint(AppleMusicTheme.accent)
                        }
                        .padding(.vertical, 2)
                    } else if songTransition == "AutoMix" {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("AutoMix DJ-Style Transitions", systemImage: "sparkles")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppleMusicTheme.accent)
                                Spacer()
                                Text("ACTIVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppleMusicTheme.accent.opacity(0.18))
                                    .foregroundStyle(AppleMusicTheme.accent)
                                    .clipShape(Capsule())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundStyle(AppleMusicTheme.accent)
                                    Text("Beat Match • Tempo alignment")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundStyle(AppleMusicTheme.accent)
                                    Text("Smart Intro/Outro • Dynamic transition anchors")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundStyle(AppleMusicTheme.accent)
                                    Text("Vocals Protection • Auto-attenuation to prevent overlap")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                }
                            }
                            
                            Text("Apple iOS 2026: AutoMix uses tempo analysis and time-stretching. Active hybrid mode blends intelligent crossfade transitions.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel.opacity(0.8))
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Song Transitions")
                }
                
                // Animated Artwork Section
                Section {
                    Picker("Animated Artwork", selection: $animatedArtworkSetting) {
                        Text("Off").tag("Off")
                        Text("Wi-Fi & Cellular").tag("Wi-Fi & Cellular")
                        Text("Wi-Fi Only").tag("Wi-Fi Only")
                    }
                } header: {
                    Text("Animated Artwork")
                } footer: {
                    Text("Supported album artwork features fluid breathing motion and artwork-derived ambient bloom.")
                }
                
                // Music Haptics Section
                Section {
                    Toggle("Music Haptics", isOn: $musicHapticsEnabled)
                        .onChange(of: musicHapticsEnabled) { _, enabled in
                            MusicHapticsManager.shared.isEnabled = enabled
                        }
                    
                    if musicHapticsEnabled {
                        Picker("Intensity", selection: $musicHapticsIntensity) {
                            ForEach(MusicHapticsIntensity.allCases) { item in
                                Text(item.rawValue).tag(item.rawValue)
                            }
                        }
                        .onChange(of: musicHapticsIntensity) { _, val in
                            if let intVal = MusicHapticsIntensity(rawValue: val) {
                                MusicHapticsManager.shared.intensity = intVal
                            }
                        }
                        
                        Picker("Mode", selection: $musicHapticsMode) {
                            ForEach(MusicHapticsMode.allCases) { item in
                                Text(item.rawValue).tag(item.rawValue)
                            }
                        }
                        .onChange(of: musicHapticsMode) { _, val in
                            if let modeVal = MusicHapticsMode(rawValue: val) {
                                MusicHapticsManager.shared.mode = modeVal
                            }
                        }
                    }
                } header: {
                    Text("Music Haptics")
                } footer: {
                    Text("Apple Music Haptics produces tactile taps, textures, and rhythm synchronized to your music.")
                }
                
                // Audio & Playback Section
                Section("Audio & Playback") {
                    Toggle("Show Song Durations", isOn: $mainTVM.options.showSongDurations)
                    Toggle("Show Rewind Button", isOn: $mainTVM.options.showRewindButton)
                    Toggle("Autoplay Similar Music (Radio)", isOn: $mainTVM.options.autoplay)
                    Toggle("Dolby Atmos", isOn: $dolbyAtmos)
                    Toggle("Sound Check", isOn: $soundCheck)
                    
                    HStack {
                        Text("Audio Quality")
                        Spacer()
                        Text(audioQuality)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 14))
                    }
                    
                    HStack {
                        Text("Playback Engine")
                        Spacer()
                        Text(PlayerEngine.shared.activeEngineName)
                            .foregroundStyle(PlayerEngine.shared.isUsingNativeEngine ? AppleMusicTheme.accent : .secondary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                
                // Diagnostics Section
                Section("Playback Diagnostics (WebKit EmbedPlayer)") {
                    HStack {
                        Text("Build Version")
                        Spacer()
                        Text("v2.0.37 (Playlist Playground, Haptics & Song Transitions)")
                            .foregroundStyle(AppleMusicTheme.accent)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("WebKit EmbedPlayer")
                            .foregroundStyle(AppleMusicTheme.accent)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("WebView Loaded")
                        Spacer()
                        Text(WKEmbedAudioEngine.shared.diagnostics.webViewLoaded ? "Yes" : "No")
                            .foregroundStyle(WKEmbedAudioEngine.shared.diagnostics.webViewLoaded ? .green : .red)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("Player Ready")
                        Spacer()
                        Text(WKEmbedAudioEngine.shared.diagnostics.playerReady ? "Yes" : "No")
                            .foregroundStyle(WKEmbedAudioEngine.shared.diagnostics.playerReady ? .green : .secondary)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("Player State")
                        Spacer()
                        Text(WKEmbedAudioEngine.shared.diagnostics.playerState)
                            .foregroundStyle(WKEmbedAudioEngine.shared.diagnostics.playerState == "playing" ? .green : AppleMusicTheme.accent)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("Current Time")
                        Spacer()
                        Text(String(format: "%.1fs / %.1fs", WKEmbedAudioEngine.shared.diagnostics.playerCurrentTime, WKEmbedAudioEngine.shared.diagnostics.playerDuration))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Playback Rate")
                        Spacer()
                        Text(String(format: "%.1fx", WKEmbedAudioEngine.shared.diagnostics.playerRate))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack(alignment: .top) {
                        Text("Player Error")
                        Spacer()
                        Text(WKEmbedAudioEngine.shared.diagnostics.playerError)
                            .foregroundStyle(WKEmbedAudioEngine.shared.diagnostics.playerError != "None" ? .red : AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 12))
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("App State")
                        Spacer()
                        Text(WKEmbedAudioEngine.shared.diagnostics.appState)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("AudioSession Category")
                        Spacer()
                        Text(WKEmbedAudioEngine.shared.diagnostics.audioSessionCategory)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("AudioSession Active")
                        Spacer()
                        Text(WKEmbedAudioEngine.shared.diagnostics.audioSessionActive ? "Yes" : "No")
                            .foregroundStyle(WKEmbedAudioEngine.shared.diagnostics.audioSessionActive ? .green : .red)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Last Before Background")
                        Spacer()
                        Text(WKEmbedAudioEngine.shared.diagnostics.lastStateBeforeBackground)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("First After Foreground")
                        Spacer()
                        Text(WKEmbedAudioEngine.shared.diagnostics.firstStateAfterForeground)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                }
                
                // Theme & Accent Color
                Section("Appearance & Theme") {
                    Picker("Accent Color", selection: $mainTVM.options.accentTheme) {
                        ForEach(AppAccentTheme.allCases) { theme in
                            HStack {
                                Circle()
                                    .fill(theme.color)
                                    .frame(width: 14, height: 14)
                                Text(theme.rawValue)
                            }
                            .tag(theme)
                        }
                    }
                    .onChange(of: mainTVM.options.accentTheme) { _, newTheme in
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        ThemeManager.shared.currentAccent = newTheme
                    }
                    
                    Picker("Player Background", selection: $mainTVM.options.playerBackground) {
                        Text("Artwork Blur (Apple Music)").tag(PlayerBackground.default)
                        Text("Solid Accent").tag(PlayerBackground.oneColor)
                        Text("Two-Color Gradient").tag(PlayerBackground.twoColor)
                    }
                }
                
                // Storage & Cache
                Section("Storage") {
                    Button(role: .destructive) {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        URLCache.shared.removeAllCachedResponses()
                    } label: {
                        Text("Clear Artwork Cache")
                    }
                }
                
                // About Demus
                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Demus (Apple Music Edition)")
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.36")
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
            .sheet(isPresented: $isLoginSheetPresented) {
                GoogleLoginSheet()
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 70) // Padding for CompactPlayer
            }
        }
    }
}
