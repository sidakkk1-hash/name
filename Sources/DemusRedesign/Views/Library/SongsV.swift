import SwiftUI

// MARK: - SongsV (Apple Music Library Songs Screen)
/// Reconstructed library songs view with large "Library" navigation title,
/// Play and Shuffle buttons, sorting filter, and signature SongRow components.
public struct SongsV: View {
    @Bindable public var player: PlayerEngine = .shared
    @State private var sortOption: SortOption = .title
    
    enum SortOption: String, CaseIterable, Identifiable {
        case title = "Title"
        case artist = "Artist"
        case recentlyAdded = "Recently Added"
        
        var id: String { rawValue }
    }
    
    public init() {}
    
    private var sortedSongs: [Song] {
        switch sortOption {
        case .title:
            return player.queue.sorted { $0.title < $1.title }
        case .artist:
            return player.queue.sorted { $0.artistName < $1.artistName }
        case .recentlyAdded:
            return player.queue
        }
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Play & Shuffle Header Action Buttons
                    HStack(spacing: 16) {
                        Button {
                            if let first = sortedSongs.first {
                                player.play(song: first)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Play")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppleMusicTheme.secondarySystemBackground)
                            .foregroundStyle(AppleMusicTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.appleMusicCard)
                        
                        Button {
                            if let random = sortedSongs.randomElement() {
                                player.isShuffle = true
                                player.play(song: random)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Shuffle")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppleMusicTheme.secondarySystemBackground)
                            .foregroundStyle(AppleMusicTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.appleMusicCard)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    
                    // Track Count and Sort Indicator
                    HStack {
                        Text("\(player.queue.count) Songs")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        
                        Spacer()
                        
                        Menu {
                            Picker("Sort By", selection: $sortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sortOption.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(AppleMusicTheme.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Track Rows List
                    LazyVStack(spacing: 6) {
                        ForEach(sortedSongs) { song in
                            SongRow(
                                song: song,
                                isCurrentPlaying: player.currentSong?.id == song.id
                            ) {
                                player.play(song: song)
                            }
                            .padding(.horizontal, 16)
                            
                            Divider()
                                .padding(.leading, 82)
                        }
                    }
                }
                .padding(.bottom, 90) // Safe padding for CompactPlayer
            }
            .navigationTitle("Songs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .tint(AppleMusicTheme.accent)
                }
            }
        }
    }
}
