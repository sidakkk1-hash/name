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
                // Shuffle & Repeat Header Section
                Section {
                    HStack(spacing: 16) {
                        Button {
                            player.isShuffle.toggle()
                        } label: {
                            HStack {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Shuffle")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(player.isShuffle ? AppleMusicTheme.accent : AppleMusicTheme.secondarySystemBackground)
                            .foregroundStyle(player.isShuffle ? .white : AppleMusicTheme.label)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            player.isRepeat.toggle()
                        } label: {
                            HStack {
                                Image(systemName: "repeat")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Repeat")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(player.isRepeat ? AppleMusicTheme.accent : AppleMusicTheme.secondarySystemBackground)
                            .foregroundStyle(player.isRepeat ? .white : AppleMusicTheme.label)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                Section("Playing Next") {
                    ForEach(player.queue.filter { $0.id != player.currentSong?.id }) { song in
                        SongRow(song: song, isCurrentPlaying: false) {
                            player.play(song: song)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Playing Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
