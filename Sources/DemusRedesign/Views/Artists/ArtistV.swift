import SwiftUI

// MARK: - ArtistV (1:1 Apple Music Artist Experience)
/// Native Apple Music artist profile view featuring:
/// - Full edge-to-edge hero image with bottom blur gradient
/// - Prominent artist name
/// - Action buttons: Info (bio), Large White Play button, Favorite star
/// - "Latest Release" glass banner
/// - "Top Songs" section with direct tap-to-play
/// - "Albums" and "Singles & EPs" carousels
/// - "Fans Might Also Like" / Similar artists carousel
public struct ArtistV: View {
    public let browseId: String
    public let initialArtist: Artist?
    
    @Bindable public var player: PlayerEngine = .shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentArtist: Artist
    @State private var isLoading: Bool = false
    @State private var isShowingBio: Bool = false
    @State private var isFavorite: Bool = false
    
    public init(browseId: String, initialArtist: Artist? = nil) {
        self.browseId = browseId
        self.initialArtist = initialArtist
        self._currentArtist = State(initialValue: initialArtist ?? Artist(id: browseId, name: "Artist"))
    }
    
    public init(artist: Artist) {
        self.init(browseId: artist.id, initialArtist: artist)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Edge-to-Edge Hero Header
                ZStack(alignment: .bottom) {
                    // Hero Image
                    heroImageView
                        .frame(height: 390)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    
                    // Blurred gradient overlay fading into dark backdrop
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black.opacity(0.15), location: 0.4),
                            .init(color: .black.opacity(0.65), location: 0.75),
                            .init(color: AppleMusicTheme.background, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Artist Name & Action Controls
                    VStack(spacing: 16) {
                        Text(currentArtist.name)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
                            .padding(.horizontal, 24)
                        
                        // Three Apple Music action buttons: Info, Play, Favorite
                        HStack(spacing: 20) {
                            // Info Button
                            Button {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                isShowingBio = true
                            } label: {
                                Image(systemName: "info")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            
                            // Dominant Play Button (Large White Circle)
                            Button {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                if !currentArtist.topSongs.isEmpty {
                                    player.playAll(songs: currentArtist.topSongs, startingAt: 0, shuffle: false)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 66, height: 66)
                                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
                                    
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.black)
                                        .offset(x: 2)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // Favorite Star Button
                            Button {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                isFavorite.toggle()
                            } label: {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(isFavorite ? AppleMusicTheme.accent : .white)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 14)
                }
                
                // Loading Indicator
                if isLoading {
                    ProgressView()
                        .tint(AppleMusicTheme.accent)
                        .padding(.vertical, 20)
                }
                
                // 2. Latest Release Card (Reference Image 1)
                if let latest = currentArtist.latestRelease {
                    VStack(alignment: .leading, spacing: 10) {
                        NavigationLink {
                            AlbumV(browseId: latest.id, initialAlbum: latest)
                        } label: {
                            HStack(spacing: 14) {
                                // Thumbnail
                                ZStack {
                                    if let url = ImageHelper.highResArtworkURL(from: latest.artworkURL, resolution: .card) {
                                        CachedAsyncImage(url: url) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                        }
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .frame(width: 68, height: 68)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                
                                // Text info
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(latest.releaseDate ?? latest.year ?? "Latest Release")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                    
                                    Text(latest.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppleMusicTheme.label)
                                        .lineLimit(1)
                                    
                                    Text(latest.albumType ?? (latest.trackCount != nil ? "\(latest.trackCount!) songs" : "Single"))
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                }
                                
                                Spacer()
                                
                                // Plus / Add Button
                                Button {
                                    #if canImport(UIKit)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    #endif
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(AppleMusicTheme.label)
                                        .frame(width: 34, height: 34)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppleMusicTheme.secondarySystemBackground)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }
                
                // 3. Top Songs Section
                if !currentArtist.topSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Top Songs")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.label)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        LazyVStack(spacing: 4) {
                            ForEach(Array(currentArtist.topSongs.prefix(10).enumerated()), id: \.element.id) { index, song in
                                SongRow(
                                    song: song,
                                    isCurrentPlaying: player.currentSong?.id == song.id
                                ) {
                                    player.playAll(songs: currentArtist.topSongs, startingAt: index, shuffle: false)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                
                // 4. Albums Carousel
                if !currentArtist.albums.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Albums")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.label)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(currentArtist.albums) { album in
                                    NavigationLink {
                                        AlbumV(browseId: album.id, initialAlbum: album)
                                    } label: {
                                        AlbumCard(album: album, size: 155) {
                                            // NavigationLink handles navigation
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                // 5. Singles & EPs Carousel
                if !currentArtist.singles.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Singles & EPs")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.label)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(currentArtist.singles) { single in
                                    NavigationLink {
                                        AlbumV(browseId: single.id, initialAlbum: single)
                                    } label: {
                                        AlbumCard(album: single, size: 145) {
                                            // NavigationLink handles navigation
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                // 6. Similar Artists Carousel (Fans Might Also Like)
                if !currentArtist.relatedArtists.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Fans Might Also Like")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.label)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(currentArtist.relatedArtists) { related in
                                    NavigationLink {
                                        ArtistV(browseId: related.id, initialArtist: related)
                                    } label: {
                                        ArtistCard(artist: related, diameter: 120) {
                                            // NavigationLink handles navigation
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                Spacer(minLength: 110) // Room for CompactPlayer
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Circular Back Button on top left
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
            
            // Share and More on top right
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    ShareLink(item: "Check out \(currentArtist.name) on Demus!") {
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
                            Label(isFavorite ? "Unfavorite Artist" : "Favorite Artist", systemImage: isFavorite ? "star.fill" : "star")
                        }
                        
                        if let firstSong = currentArtist.topSongs.first {
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
        .sheet(isPresented: $isShowingBio) {
            artistBioSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await loadArtistData()
        }
    }
    
    // MARK: - Hero Image View
    @ViewBuilder
    private var heroImageView: some View {
        if let heroUrl = currentArtist.heroImageURL ?? currentArtist.artworkURL {
            CachedAsyncImage(url: heroUrl) { img in
                img
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                heroPlaceholder
            }
        } else {
            heroPlaceholder
        }
    }
    
    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.35), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            Image(systemName: "person.crop.rectangle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
    
    // MARK: - Artist Bio Sheet
    private var artistBioSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let subs = currentArtist.subscribers, !subs.isEmpty {
                        Text(subs)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppleMusicTheme.accent)
                    }
                    
                    if let bio = currentArtist.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.label)
                            .lineSpacing(5)
                    } else {
                        Text("No biography available for this artist.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    }
                }
                .padding(24)
            }
            .navigationTitle(currentArtist.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingBio = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppleMusicTheme.accent)
                }
            }
        }
    }
    
    // MARK: - Load Artist Data
    private func loadArtistData() async {
        guard currentArtist.topSongs.isEmpty || currentArtist.albums.isEmpty else { return }
        isLoading = true
        if let fetched = await BrowseService.shared.fetchArtist(id: browseId) {
            currentArtist = fetched
        }
        isLoading = false
    }
}
