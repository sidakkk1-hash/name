import SwiftUI

// MARK: - AlbumV (1:1 Apple Music Dynamic Album Experience)
/// Displays an album with:
/// - Dynamic artwork-derived blurred background tint
/// - Large centered squircle artwork with deep ambient shadow
/// - Tappable Artist Name navigating directly to ArtistV
/// - Play & Shuffle action buttons
/// - Tracklist with track numbers, explicit badges, durations, and context menus
public struct AlbumV: View {
    public let browseId: String
    public let initialAlbum: Album?
    
    @Bindable public var player: PlayerEngine = .shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentAlbum: Album
    @State private var isLoading: Bool = false
    @State private var isFavorite: Bool = false
    
    public init(browseId: String, initialAlbum: Album? = nil) {
        self.browseId = browseId
        self.initialAlbum = initialAlbum
        self._currentAlbum = State(initialValue: initialAlbum ?? Album(id: browseId, title: "Album", artist: ""))
    }
    
    public init(album: Album) {
        self.init(browseId: album.id, initialAlbum: album)
    }
    
    // Artwork-derived dynamic ambient color
    private var ambientColor: Color {
        let hash = abs(currentAlbum.title.hashValue ^ currentAlbum.artist.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.28)
    }
    
    public var body: some View {
        ZStack {
            // Dynamic Artwork Tint Background (Reference Images 2 & 3)
            LinearGradient(
                stops: [
                    .init(color: ambientColor.opacity(0.85), location: 0.0),
                    .init(color: ambientColor.opacity(0.35), location: 0.45),
                    .init(color: AppleMusicTheme.systemBackground, location: 0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Centered Album Artwork
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
                    .frame(width: 230, height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
                    .padding(.top, 10)
                    
                    // 2. Title, Tappable Artist, and Metadata
                    VStack(spacing: 6) {
                        Text(currentAlbum.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        // Tappable Artist Name -> Navigates to ArtistV
                        if let aId = currentAlbum.artistId, !aId.isEmpty {
                            NavigationLink(value: AppRoute.artist(aId)) {
                                Text(currentAlbum.artist)
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(AppleMusicTheme.accent)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(currentAlbum.artist)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(AppleMusicTheme.accent)
                        }
                        
                        // Release Metadata
                        HStack(spacing: 5) {
                            Text(currentAlbum.albumType ?? "Album")
                            Text("•")
                            Text(currentAlbum.year ?? currentAlbum.releaseDate ?? "2024")
                            Text("•")
                            HStack(spacing: 2) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 10))
                                Text("Lossless")
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    }
                    
                    // 3. Action Buttons Row (Shuffle, Play, Favorite)
                    HStack(spacing: 14) {
                        // Shuffle Button
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            if !currentAlbum.songs.isEmpty {
                                player.playAll(songs: currentAlbum.songs, startingAt: 0, shuffle: true)
                            }
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        // Large Play Pill
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            if !currentAlbum.songs.isEmpty {
                                player.playAll(songs: currentAlbum.songs, startingAt: 0, shuffle: false)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Play")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        
                        // Add to Library / Favorite Button
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            isFavorite.toggle()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isFavorite ? AppleMusicTheme.accent : .white)
                                .frame(width: 48, height: 48)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    
                    // Editorial Description if available
                    if let desc = currentAlbum.descriptionText, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .lineLimit(3)
                            .padding(.horizontal, 24)
                    }
                    
                    // Loading Spinner
                    if isLoading {
                        ProgressView()
                            .tint(AppleMusicTheme.accent)
                            .padding(.vertical, 20)
                    }
                    
                    // 4. Track List
                    if !currentAlbum.songs.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(currentAlbum.songs.enumerated()), id: \.element.id) { index, song in
                                trackRow(index: index, song: song)
                                
                                if index < currentAlbum.songs.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // 5. Album Footer Details
                        VStack(spacing: 5) {
                            let totalSecs = currentAlbum.songs.reduce(0) { $0 + $1.duration }
                            let minutes = Int(totalSecs / 60)
                            Text("\(currentAlbum.songs.count) Songs\(minutes > 0 ? ", \(minutes) Minutes" : "")")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            
                            if let release = currentAlbum.releaseDate, !release.isEmpty {
                                Text("Released \(release)")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(AppleMusicTheme.tertiaryLabel)
                            }
                            
                            Text("℗ Lossless Audio • Apple Music Master")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(AppleMusicTheme.tertiaryLabel)
                        }
                        .padding(.top, 24)
                    } else if !isLoading {
                        ContentUnavailableView {
                            Label("No Tracks Found", systemImage: "music.note")
                        } description: {
                            Text("This album does not have available tracks.")
                        } actions: {
                            Button("Retry") {
                                Task {
                                    await loadAlbumData()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppleMusicTheme.accent)
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 110) // Room for CompactPlayer
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    ShareLink(item: "Check out \(currentAlbum.title) by \(currentAlbum.artist) on Demus!") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Menu {
                        Button {
                            isFavorite.toggle()
                        } label: {
                            Label(isFavorite ? "Unfavorite Album" : "Favorite Album", systemImage: isFavorite ? "star.fill" : "star")
                        }
                        
                        if let firstSong = currentAlbum.songs.first {
                            Button {
                                player.playNext(firstSong)
                            } label: {
                                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .task {
            await loadAlbumData()
        }
    }
    
    // MARK: - Track Row Component
    private func trackRow(index: Int, song: Song) -> some View {
        let isCurrent = player.currentSong?.id == song.id
        
        return HStack(spacing: 16) {
            // Track Number
            Text("\(song.trackNumber ?? (index + 1))")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                .frame(width: 26, alignment: .trailing)
            
            // Title & Explicit badge
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(isCurrent ? AppleMusicTheme.accent : .white)
                        .lineLimit(1)
                    
                    if song.isExplicit {
                        Text("E")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                
                if song.artistName != currentAlbum.artist && !song.artistName.isEmpty {
                    Text(song.artistName)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Duration
            if !song.formattedDuration.isEmpty {
                Text(song.formattedDuration)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
            }
            
            // Ellipsis Menu
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
                    .font(.system(size: 15))
                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            player.playAll(songs: currentAlbum.songs, startingAt: index, shuffle: false)
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
    
    private func loadAlbumData() async {
        guard currentAlbum.songs.isEmpty else { return }
        isLoading = true
        if let fetched = await BrowseService.shared.fetchAlbum(id: browseId) {
            currentAlbum = fetched
        }
        isLoading = false
    }
}
