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
                                player.play(song: song)
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
