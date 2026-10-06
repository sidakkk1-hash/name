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
                    
                    HStack {
                        Text("Diagnostics")
                        Spacer()
                        Text(PlayerEngine.shared.diagnosticSummary)
                            .foregroundStyle(PlayerEngine.shared.isUsingNativeEngine ? AppleMusicTheme.accent : .orange)
                            .font(.system(size: 13, weight: .medium))
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
            .sheet(isPresented: $isLoginSheetPresented) {
                GoogleLoginSheet()
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 70) // Padding for CompactPlayer
            }
        }
    }
}
