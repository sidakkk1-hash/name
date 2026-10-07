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
                Section("Stream Extractor Diagnostics") {
                    HStack {
                        Text("Extractor State")
                        Spacer()
                        Text(WKStreamExtractor.shared.diagnostics.state)
                            .foregroundStyle(WKStreamExtractor.shared.diagnostics.state == "found" ? .green : (WKStreamExtractor.shared.diagnostics.state == "failed" ? .red : AppleMusicTheme.accent))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("Extractor Host")
                        Spacer()
                        Text(WKStreamExtractor.shared.diagnostics.host)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Elapsed Time")
                        Spacer()
                        Text(String(format: "%.2fs", WKStreamExtractor.shared.diagnostics.elapsedTime))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    if let fail = WKStreamExtractor.shared.diagnostics.failure {
                        HStack(alignment: .top) {
                            Text("Failure")
                            Spacer()
                            Text(fail)
                                .foregroundStyle(.red)
                                .font(.system(size: 12))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                Section("Native Player Diagnostics (AVPlayer)") {
                    HStack {
                        Text("Build Version")
                        Spacer()
                        Text("v2.0.29 (Native AVPlayer + WebKit Extractor)")
                            .foregroundStyle(AppleMusicTheme.accent)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("Native AVPlayer")
                            .foregroundStyle(AppleMusicTheme.accent)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("Item Status")
                        Spacer()
                        Text(NativeAudioEngine.shared.diagnostics.itemStatus)
                            .foregroundStyle(NativeAudioEngine.shared.diagnostics.itemStatus == "readyToPlay" ? .green : (NativeAudioEngine.shared.diagnostics.itemStatus == "failed" ? .red : AppleMusicTheme.accent))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack(alignment: .top) {
                        Text("Item Error")
                        Spacer()
                        Text(NativeAudioEngine.shared.diagnostics.itemError)
                            .foregroundStyle(NativeAudioEngine.shared.diagnostics.itemError != "None" ? .red : AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 12))
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Time Control Status")
                        Spacer()
                        Text(NativeAudioEngine.shared.diagnostics.timeControlStatus)
                            .foregroundStyle(NativeAudioEngine.shared.diagnostics.timeControlStatus == "playing" ? .green : AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("Waiting Reason")
                        Spacer()
                        Text(NativeAudioEngine.shared.diagnostics.waitingReason)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Rate")
                        Spacer()
                        Text(String(format: "%.1f", NativeAudioEngine.shared.diagnostics.rate))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Current Time")
                        Spacer()
                        Text(String(format: "%.1fs / %.1fs", NativeAudioEngine.shared.diagnostics.currentTime, NativeAudioEngine.shared.diagnostics.duration))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Playback Stalled")
                        Spacer()
                        Text(NativeAudioEngine.shared.diagnostics.playbackStalled ? "Yes" : "No")
                            .foregroundStyle(NativeAudioEngine.shared.diagnostics.playbackStalled ? .orange : .green)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Stream Host")
                        Spacer()
                        Text(NativeAudioEngine.shared.diagnostics.lastStreamHost)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("AVAudioSession Category")
                        Spacer()
                        Text(PlayerEngine.shared.audioSessionCategoryString)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("App State")
                        Spacer()
                        Text(NativeAudioEngine.shared.diagnostics.appState)
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
                        Text("2.0.29")
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
