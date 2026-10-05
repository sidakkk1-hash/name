import SwiftUI

// MARK: - SongsV (Apple Music Library Songs Screen)
/// Reconstructed library songs view with large "Library" navigation title,
/// Play and Shuffle buttons, sorting filter, and signature SongRow components.
public struct SongsV: View {
    @Bindable public var player: PlayerEngine = .shared
    @State private var sortOption: SortOption = .title
    @State private var librarySongs: [Song] = LibraryRepository.shared.librarySongs
    
    @State private var showFavoritesOnly: Bool = false
    
    enum SortOption: String, CaseIterable, Identifiable {
        case title = "Title"
        case artist = "Artist"
        case recentlyAdded = "Recently Added"
        
        var id: String { rawValue }
    }
    
    public init() {}
    
    private var displaySongs: [Song] {
        var base = librarySongs
        if showFavoritesOnly {
            base = base.filter { $0.isFavorite }
        }
        switch sortOption {
        case .title:
            return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return base.sorted { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
        case .recentlyAdded:
            return base
        }
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                if displaySongs.isEmpty {
                    ContentUnavailableView {
                        Label(showFavoritesOnly ? "No Favorite Songs" : "No Songs in Library", systemImage: showFavoritesOnly ? "star" : "music.note")
                    } description: {
                        Text(showFavoritesOnly ? "Favorite tracks by tapping the star icon." : "Search for songs and play or add them to your library.")
                    }
                    .padding(.top, 80)
                } else {
                    VStack(spacing: 16) {
                        // Play & Shuffle Header Action Buttons
                        HStack(spacing: 16) {
                            Button {
                                player.playAll(songs: displaySongs, startingAt: 0, shuffle: false)
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
                                player.playAll(songs: displaySongs, startingAt: 0, shuffle: true)
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
                            Text("\(displaySongs.count) Songs")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    showFavoritesOnly.toggle()
                                }
                            } label: {
                                Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                                    .font(.system(size: 15))
                                    .foregroundStyle(showFavoritesOnly ? AppleMusicTheme.accent : AppleMusicTheme.secondaryLabel)
                                    .padding(.trailing, 8)
                            }
                            
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
                            ForEach(Array(displaySongs.enumerated()), id: \.element.id) { index, song in
                                SongRow(
                                    song: song,
                                    isCurrentPlaying: player.currentSong?.id == song.id
                                ) {
                                    player.playAll(songs: displaySongs, startingAt: index, shuffle: false)
                                }
                                .padding(.horizontal, 16)
                                
                                Divider()
                                    .padding(.leading, 82)
                            }
                        }
                    }
                    .padding(.bottom, 90) // Safe padding for CompactPlayer
                }
            }
            .navigationTitle("Songs")
            .onAppear {
                self.librarySongs = LibraryRepository.shared.librarySongs
            }
        }
    }
}
