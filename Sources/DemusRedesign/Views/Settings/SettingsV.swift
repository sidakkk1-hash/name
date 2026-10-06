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
                // Diagnostics Section
                Section("Playback Diagnostics & Controls") {
                    HStack {
                        Text("Build Version")
                        Spacer()
                        Text("v2.0.25 (Scientific Native)")
                            .foregroundStyle(AppleMusicTheme.accent)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    
                    Toggle("Force Native-Only Engine", isOn: Binding(
                        get: { PlayerEngine.shared.forceNativeOnly },
                        set: { PlayerEngine.shared.forceNativeOnly = $0 }
                    ))
                    .tint(.green)
                    
                    HStack {
                        Text("Active Engine")
                        Spacer()
                        Text(PlayerEngine.shared.activeEngineName)
                            .foregroundStyle(PlayerEngine.shared.isUsingNativeEngine ? AppleMusicTheme.accent : .secondary)
                            .font(.system(size: 13, weight: .medium))
                    }
                    HStack {
                        Text("Native Confirmed (>=3s)")
                        Spacer()
                        Text(PlayerEngine.shared.nativePlaybackConfirmed ? "Yes" : "No")
                            .foregroundStyle(PlayerEngine.shared.nativePlaybackConfirmed ? .green : .secondary)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("AVPlayer Item Status")
                        Spacer()
                        Text(NativeAudioEngine.shared.itemStatusString)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Time Control Status")
                        Spacer()
                        Text(NativeAudioEngine.shared.timeControlStatusString)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Current Time")
                        Spacer()
                        Text(String(format: "%.1fs", PlayerEngine.shared.currentTime))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Player Rate")
                        Spacer()
                        Text(String(format: "%.1f", NativeAudioEngine.shared.player.rate))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("Audio Session Category")
                        Spacer()
                        Text(PlayerEngine.shared.audioSessionCategoryString)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("App State")
                        Spacer()
                        Text(PlayerEngine.shared.appStateString)
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 13))
                    }
                }
                
                // Stream Validation Diagnostics
                if let streamDiag = StreamResolutionService.shared.latestDiagnostic {
                    Section("Stream Resource Validation") {
                        HStack {
                            Text("URL Host")
                            Spacer()
                            Text(streamDiag.urlHost)
                                .font(.system(size: 12))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        }
                        HStack {
                            Text("HTTP Validation Status")
                            Spacer()
                            Text("\(streamDiag.httpStatus)")
                                .foregroundStyle(streamDiag.httpStatus == 200 || streamDiag.httpStatus == 206 ? .green : .red)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        HStack {
                            Text("Content-Type")
                            Spacer()
                            Text(streamDiag.contentType)
                                .font(.system(size: 12))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        }
                        HStack {
                            Text("Accept-Ranges")
                            Spacer()
                            Text(streamDiag.acceptRanges)
                                .font(.system(size: 13))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        }
                        HStack {
                            Text("Content-Range")
                            Spacer()
                            Text(streamDiag.contentRange)
                                .font(.system(size: 12))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        }
                        HStack {
                            Text("Codec & Bitrate")
                            Spacer()
                            Text("\(streamDiag.codec) (\(streamDiag.bitrate / 1000) kbps)")
                                .font(.system(size: 13))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        }
                    }
                }
                
                // AVFoundation Asset & Error Diagnostics
                Section("AVFoundation Diagnostics") {
                    if let assetDiag = NativeAudioEngine.shared.latestAssetDiagnostic {
                        HStack {
                            Text("Asset isPlayable")
                            Spacer()
                            Text(assetDiag.isPlayable ? "True" : "False")
                                .foregroundStyle(assetDiag.isPlayable ? .green : .red)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        HStack {
                            Text("Asset Duration")
                            Spacer()
                            Text(String(format: "%.1fs", assetDiag.durationSeconds))
                                .font(.system(size: 13))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        }
                        HStack {
                            Text("Tracks")
                            Spacer()
                            Text("\(assetDiag.tracksCount) (\(assetDiag.trackMediaTypes.joined(separator: ", ")))")
                                .font(.system(size: 12))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        }
                    }
                    
                    HStack(alignment: .top) {
                        Text("Last Error")
                        Spacer()
                        Text(PlayerEngine.shared.lastFailureReason ?? "None")
                            .foregroundStyle(PlayerEngine.shared.lastFailureReason != nil ? .orange : AppleMusicTheme.secondaryLabel)
                            .font(.system(size: 12))
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if let errDiag = NativeAudioEngine.shared.latestErrorDiagnostic {
                        if errDiag.errorLogEvents != "none" {
                            HStack(alignment: .top) {
                                Text("errorLog")
                                Spacer()
                                Text(errDiag.errorLogEvents)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        if errDiag.accessLogEvents != "none" {
                            HStack(alignment: .top) {
                                Text("accessLog")
                                Spacer()
                                Text(errDiag.accessLogEvents)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                
                // Background Snapshots Section
                if !PlayerEngine.shared.diagnosticSnapshots.isEmpty {
                    Section("Background Lifecycle Snapshots") {
                        ForEach(PlayerEngine.shared.diagnosticSnapshots) { snap in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(snap.label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppleMusicTheme.accent)
                                    Spacer()
                                    Text(String(format: "Time: %.1fs | Rate: %.1f", snap.currentTime, snap.rate))
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                }
                                Text("Status: \(snap.itemStatus) | TC: \(snap.timeControlStatus) | Category: \(snap.audioSessionCategory)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                if snap.lastNativeError != "None" {
                                    Text("Err: \(snap.lastNativeError)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(.vertical, 2)
                        }
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
