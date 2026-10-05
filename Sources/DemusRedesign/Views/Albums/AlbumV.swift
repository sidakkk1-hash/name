import SwiftUI

// MARK: - AlbumV (Apple Music Album Detail View)
/// Displays an album with large hero artwork, release metadata, Play and Shuffle action buttons, and full tracklist.
public struct AlbumV: View {
    public let album: Album
    @Bindable public var player: PlayerEngine = .shared
    
    @State private var currentAlbum: Album
    @State private var isLoading: Bool = false
    
    public init(album: Album) {
        self.album = album
        self._currentAlbum = State(initialValue: album)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large Centered Artwork
                ZStack {
                    if let rawUrl = currentAlbum.artworkURL, let url = ImageHelper.highResArtworkURL(from: rawUrl, resolution: .card) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            placeholderImage
                        }
                    } else {
                        placeholderImage
                    }
                }
                .frame(width: 240, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: AppleMusicTheme.radiusLargeCard, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppleMusicTheme.radiusLargeCard, style: .continuous)
                        .stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.20), radius: 18, x: 0, y: 10)
                .padding(.top, 12)
                
                // Album Title & Metadata
                VStack(spacing: 4) {
                    Text(currentAlbum.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppleMusicTheme.label)
                        .multilineTextAlignment(.center)
                    
                    Text(currentAlbum.artist)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(AppleMusicTheme.accent)
                    
                    if let release = currentAlbum.releaseDate, !release.isEmpty {
                        Text(release)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    }
                }
                .padding(.horizontal, 20)
                
                // Action Buttons (Play & Shuffle)
                if !currentAlbum.songs.isEmpty {
                    HStack(spacing: 16) {
                        Button {
                            player.playAll(songs: currentAlbum.songs, startingAt: 0, shuffle: false)
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
                            player.playAll(songs: currentAlbum.songs, startingAt: 0, shuffle: true)
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
                    .padding(.horizontal, 20)
                }
                
                // Loading Spinner
                if isLoading {
                    ProgressView()
                        .tint(AppleMusicTheme.accent)
                        .padding(.vertical, 30)
                }
                
                // Track List
                if !currentAlbum.songs.isEmpty {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(currentAlbum.songs.enumerated()), id: \.element.id) { index, song in
                            HStack(spacing: 16) {
                                Text("\(index + 1)")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                    .frame(width: 24, alignment: .trailing)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(player.currentSong?.id == song.id ? AppleMusicTheme.accent : AppleMusicTheme.label)
                                        .lineLimit(1)
                                    
                                    Text(song.artistName)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Menu {
                                    Button {
                                        player.playNext(song)
                                    } label: {
                                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                                    }
                                    
                                    Button {
                                        player.addToQueue(song)
                                    } label: {
                                        Label("Play Later", systemImage: "text.line.last.and.arrowtriangle.forward")
                                    }
                                    
                                    Button {
                                        player.toggleFavorite(for: song.id)
                                    } label: {
                                        Label(song.isFavorite ? "Unfavorite" : "Favorite", systemImage: song.isFavorite ? "star.fill" : "star")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16))
                                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.playAll(songs: currentAlbum.songs, startingAt: index, shuffle: false)
                            }
                            
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                    
                    // Album Footer Details
                    VStack(spacing: 6) {
                        let totalSecs = currentAlbum.songs.reduce(0) { $0 + $1.duration }
                        let minutes = Int(totalSecs / 60)
                        Text("\(currentAlbum.songs.count) Songs\(minutes > 0 ? ", \(minutes) Minutes" : "")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        
                        if let release = currentAlbum.releaseDate, !release.isEmpty {
                            Text("Released \(release)")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(AppleMusicTheme.tertiaryLabel)
                        }
                    }
                    .padding(.top, 16)
                } else if !isLoading {
                    ContentUnavailableView {
                        Label("No Tracks Found", systemImage: "music.note")
                    } description: {
                        Text("This album does not have available tracks.")
                    }
                    .padding(.top, 20)
                }
                
                Spacer(minLength: 100) // Padding for CompactPlayer
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if currentAlbum.songs.isEmpty {
                isLoading = true
                if let fetched = await BrowseService.shared.fetchAlbum(id: album.id) {
                    currentAlbum = fetched
                }
                isLoading = false
            }
        }
    }
    
    private var placeholderImage: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Image(systemName: "opticaldisc")
                .font(.system(size: 70))
                .foregroundStyle(.secondary)
        }
    }
}
