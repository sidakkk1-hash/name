import SwiftUI

// MARK: - QueueV (Playing Next / Queue View)
/// Apple Music-inspired "Playing Next" view with Shuffle, Repeat, and interactive queue list.
public struct QueueV: View {
    @Bindable public var player: PlayerEngine
    @Environment(\.dismiss) private var dismiss
    
    public init(player: PlayerEngine = .shared) {
        self.player = player
    }
    
    public var body: some View {
        NavigationStack {
            List {
                // Playback Controls Action Bar (AutoPlay, Crossfade, Shuffle, Repeat)
                Section {
                    HStack(spacing: 8) {
                        // ∞ AutoPlay (Subtle red active state)
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            player.isAutoplayEnabled.toggle()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "infinity")
                                    .font(.system(size: 13, weight: .bold))
                                Text("AutoPlay")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(player.isAutoplayEnabled ? Color(red: 0.98, green: 0.15, blue: 0.28).opacity(0.85) : AppleMusicTheme.secondarySystemBackground)
                            .foregroundStyle(player.isAutoplayEnabled ? .white : AppleMusicTheme.label)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        // Crossfade Toggle
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            player.isCrossfadeEnabled.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform.badge.magnifyingglass")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Crossfade")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(player.isCrossfadeEnabled ? AppleMusicTheme.accent.opacity(0.85) : AppleMusicTheme.secondarySystemBackground)
                            .foregroundStyle(player.isCrossfadeEnabled ? .white : AppleMusicTheme.label)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        // Shuffle Button
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            player.isShuffle.toggle()
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 42)
                                .padding(.vertical, 9)
                                .background(player.isShuffle ? AppleMusicTheme.accent : AppleMusicTheme.secondarySystemBackground)
                                .foregroundStyle(player.isShuffle ? .white : AppleMusicTheme.label)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        // Repeat Button
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            player.isRepeat.toggle()
                        } label: {
                            Image(systemName: "repeat")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 42)
                                .padding(.vertical, 9)
                                .background(player.isRepeat ? AppleMusicTheme.accent : AppleMusicTheme.secondarySystemBackground)
                                .foregroundStyle(player.isRepeat ? .white : AppleMusicTheme.label)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                    .listRowBackground(Color.clear)
                }
                
                // Currently Playing Track
                if let currentSong = player.currentSong {
                    Section("Now Playing") {
                        SongRow(song: currentSong, isCurrentPlaying: true) {
                            // Already playing
                        }
                    }
                }
                
                // Playing Next Tracks
                let upcoming = player.queue.filter { $0.id != player.currentSong?.id }
                Section {
                    if upcoming.isEmpty {
                        Text("No upcoming songs in queue")
                            .font(.system(size: 14))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(upcoming) { song in
                            SongRow(song: song, isCurrentPlaying: false) {
                                player.skipToQueueItem(song)
                            }
                        }
                        .onDelete { indexSet in
                            let idsToRemove = indexSet.map { upcoming[$0].id }
                            for id in idsToRemove {
                                player.removeFromQueue(id: id)
                            }
                        }
                        .onMove { indices, newOffset in
                            player.moveInQueue(from: indices, to: newOffset)
                        }
                    }
                } header: {
                    HStack {
                        Text("Playing Next")
                        Spacer()
                        if !upcoming.isEmpty {
                            Button("Clear") {
                                player.clearQueue()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppleMusicTheme.accent)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Playing Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .tint(AppleMusicTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            player.isCrossfadeEnabled.toggle()
                        } label: {
                            Image(systemName: player.isCrossfadeEnabled ? "waveform.badge.magnifyingglass" : "waveform")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(player.isCrossfadeEnabled ? AppleMusicTheme.accent : AppleMusicTheme.secondaryLabel)
                        }
                        
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .tint(AppleMusicTheme.accent)
                    }
                }
            }
        }
    }
}
