import SwiftUI

// MARK: - SearchV (1:1 Apple Music Search Experience)
/// Reconstructed Search view with:
/// - 5 native Apple Music sections & filter tabs: Top Results, Songs, Albums, Artists, Playlists
/// - Top Results best-match cards
/// - Horizontal carousels with "See All >"
/// - Full interactive navigation to ArtistV, AlbumV, PlaylistDetailV, and Song playback
/// - Recent searches & vibrant 2-column Browse Categories
public struct SearchV: View {
    @Bindable public var searchVM: SearchVM = SearchVM.shared
    @Bindable public var player: PlayerEngine = .shared
    
    private let categoryColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if searchVM.query.isEmpty {
                        emptyQueryBrowseView
                    } else {
                        searchResultsView
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 110) // Room for docked MiniPlayer
            }
            .navigationTitle("Search")
            .searchable(
                text: $searchVM.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Artists, Songs, Albums, Playlists"
            )
            .searchSuggestions {
                ForEach(searchVM.suggestions, id: \.self) { suggestion in
                    Button {
                        searchVM.query = suggestion
                        searchVM.performSearch()
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            Text(suggestion)
                                .foregroundStyle(AppleMusicTheme.label)
                            Spacer()
                        }
                    }
                }
            }
            .onChange(of: searchVM.query) { _, newQuery in
                if newQuery.isEmpty {
                    searchVM.clearResults()
                } else {
                    searchVM.fetchSuggestions()
                    searchVM.performSearch()
                }
            }
            // MARK: AppRoute destination handler — required for SongRow artist/album links
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .artist(let browseId):
                    // Prefer matched artist; fallback to stub from songs list (ArtistV fetches full data)
                    let matchedArtist = searchVM.matchedArtists.first(where: { $0.id == browseId })
                    let stubArtist = searchVM.searchResults.compactMap({ s -> Artist? in
                        guard s.artistBrowseId == browseId || s.artistId == browseId else { return nil }
                        return Artist(id: browseId, name: s.artistName)
                    }).first
                    ArtistV(browseId: browseId, initialArtist: matchedArtist ?? stubArtist)
                case .album(let browseId):
                    // Look up in matched albums; fallback to stub (AlbumV will fetch)
                    let album = searchVM.matchedAlbums.first(where: { $0.id == browseId })
                    AlbumV(browseId: browseId, initialAlbum: album)
                case .playlist(let playlistId):
                    let pl = searchVM.matchedPlaylists.first(where: { $0.id == playlistId })
                        ?? Playlist(id: playlistId, title: "Playlist")
                    PlaylistDetailV(playlist: pl)
                }
            }
            .toolbar {
                if !searchVM.query.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            searchVM.query = ""
                            searchVM.clearResults()
                        }
                        .foregroundStyle(AppleMusicTheme.accent)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Query View (Recent Searches & Browse Categories)
    private var emptyQueryBrowseView: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Recent Searches
            if !searchVM.searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Recent Searches")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        Spacer()
                        Button("Clear") {
                            LibraryRepository.shared.clearSearchHistory()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppleMusicTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    
                    ForEach(searchVM.searchHistory, id: \.self) { query in
                        HStack {
                            Button {
                                searchVM.query = query
                                searchVM.performSearch()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 15))
                                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                                    
                                    Text(query)
                                        .font(.system(size: 16))
                                        .foregroundStyle(AppleMusicTheme.label)
                                    
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                LibraryRepository.shared.removeSearchQuery(query)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppleMusicTheme.tertiaryLabel)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Browse Categories 2-Column Grid
            VStack(alignment: .leading, spacing: 14) {
                Text("Browse Categories")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppleMusicTheme.label)
                    .padding(.horizontal, 16)
                
                LazyVGrid(columns: categoryColumns, spacing: 14) {
                    ForEach(searchVM.categories) { category in
                        CategoryCard(category: category) {
                            searchVM.query = category.title
                            searchVM.performSearch()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Apple Music 5-Section Filter Tabs (Pills)
            filterTabsBar
            
            if searchVM.isSearching && searchVM.searchResults.isEmpty && searchVM.matchedAlbums.isEmpty && searchVM.matchedArtists.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppleMusicTheme.accent)
                        .padding(.top, 40)
                    Spacer()
                }
            } else if !searchVM.isSearching && searchVM.searchResults.isEmpty && searchVM.matchedAlbums.isEmpty && searchVM.matchedArtists.isEmpty && searchVM.matchedPlaylists.isEmpty && searchVM.topResults.isEmpty {
                ContentUnavailableView.search(text: searchVM.query)
                    .padding(.top, 40)
            } else {
                switch searchVM.selectedSection {
                case .topResults:
                    topResultsSectionView
                case .songs:
                    allSongsSectionView
                case .albums:
                    allAlbumsSectionView
                case .artists:
                    allArtistsSectionView
                case .playlists:
                    allPlaylistsSectionView
                }
            }
        }
    }
    
    // MARK: - 5-Category Filter Tabs Bar
    private var filterTabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchSectionFilter.allCases) { section in
                    let isSelected = searchVM.selectedSection == section
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        withAnimation(AppleMusicTheme.springAnimation) {
                            searchVM.selectedSection = section
                        }
                    } label: {
                        Text(section.rawValue)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? .white : AppleMusicTheme.label)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? AppleMusicTheme.accent : AppleMusicTheme.secondarySystemBackground
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Top Results Overview View (Best Matches + Horizontal Carousels)
    private var topResultsSectionView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 1. Top Results Card
            if !searchVM.topResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Top Result")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppleMusicTheme.label)
                        .padding(.horizontal, 16)
                    
                    ForEach(searchVM.topResults.prefix(2)) { item in
                        topResultCard(item: item)
                            .padding(.horizontal, 16)
                    }
                }
            }
            
            // 2. Songs Section (Top 5 tracks)
            if !searchVM.searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeaderWithSeeAll(title: "Songs") {
                        withAnimation { searchVM.selectedSection = .songs }
                    }
                    
                    LazyVStack(spacing: 4) {
                        ForEach(searchVM.searchResults.prefix(5)) { song in
                            SongRow(
                                song: song,
                                isCurrentPlaying: player.currentSong?.id == song.id
                            ) {
                                player.play(song: song)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            
            // 3. Albums Horizontal Carousel
            if !searchVM.matchedAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeaderWithSeeAll(title: "Albums") {
                        withAnimation { searchVM.selectedSection = .albums }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(searchVM.matchedAlbums) { album in
                                NavigationLink(value: AppRoute.album(album.id)) {
                                    AlbumCard(album: album, size: 155)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            // 4. Artists Horizontal Carousel
            if !searchVM.matchedArtists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeaderWithSeeAll(title: "Artists") {
                        withAnimation { searchVM.selectedSection = .artists }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(searchVM.matchedArtists) { artist in
                                NavigationLink(value: AppRoute.artist(artist.id)) {
                                    ArtistCard(artist: artist, diameter: 120)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            // 5. Playlists Horizontal Carousel
            if !searchVM.matchedPlaylists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeaderWithSeeAll(title: "Playlists") {
                        withAnimation { searchVM.selectedSection = .playlists }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(searchVM.matchedPlaylists) { pl in
                                NavigationLink(value: AppRoute.playlist(pl.id)) {
                                    playlistCard(pl: pl, size: 155)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    // MARK: - Top Result Card Builder
    @ViewBuilder
    private func topResultCard(item: TopResultItem) -> some View {
        switch item {
        case .artist(let artist):
            NavigationLink(value: AppRoute.artist(artist.id)) {
                HStack(spacing: 16) {
                    // Circular Artist Portrait
                    ZStack {
                        if let url = ImageHelper.highResArtworkURL(from: artist.artworkURL, resolution: .card) {
                            CachedAsyncImage(url: url) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artist.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppleMusicTheme.label)
                            .lineLimit(1)
                        
                        Text(artist.subscribers ?? "Artist")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppleMusicTheme.secondarySystemBackground)
                )
            }
            .buttonStyle(.plain)
            
        case .album(let album):
            NavigationLink(value: AppRoute.album(album.id)) {
                HStack(spacing: 16) {
                    // Square Album Artwork
                    ZStack {
                        if let url = ImageHelper.highResArtworkURL(from: album.artworkURL, resolution: .card) {
                            CachedAsyncImage(url: url) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppleMusicTheme.label)
                            .lineLimit(1)
                        
                        Text("\(album.albumType ?? "Album") • \(album.artist)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .lineLimit(1)
                        
                        if let y = album.year ?? album.releaseDate, !y.isEmpty {
                            Text(y)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AppleMusicTheme.tertiaryLabel)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppleMusicTheme.secondarySystemBackground)
                )
            }
            .buttonStyle(.plain)
            
        case .song(let song):
            HStack(spacing: 16) {
                // Square Song Artwork
                Button {
                    player.play(song: song)
                } label: {
                    ZStack {
                        if let url = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id, resolution: .card) {
                            CachedAsyncImage(url: url) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppleMusicTheme.label)
                        .lineLimit(1)
                    
                    NavigationLink(value: AppRoute.artist(song.artistId.isEmpty ? "artist-yt" : song.artistId)) {
                        Text("Song • \(song.artistName)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button {
                    player.play(song: song)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AppleMusicTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppleMusicTheme.secondarySystemBackground)
            )
            
        case .playlist(let pl):
            NavigationLink(value: AppRoute.playlist(pl.id)) {
                HStack(spacing: 16) {
                    ZStack {
                        if let url = ImageHelper.highResArtworkURL(from: pl.artworkURL, resolution: .card) {
                            CachedAsyncImage(url: url) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pl.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppleMusicTheme.label)
                            .lineLimit(1)
                        
                        Text(pl.author ?? "Playlist")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppleMusicTheme.secondaryLabel)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppleMusicTheme.secondarySystemBackground)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - All Songs Tab View
    private var allSongsSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Songs")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppleMusicTheme.label)
                .padding(.horizontal, 16)
            
            LazyVStack(spacing: 4) {
                ForEach(searchVM.searchResults) { song in
                    SongRow(
                        song: song,
                        isCurrentPlaying: player.currentSong?.id == song.id
                    ) {
                        player.play(song: song)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - All Albums Tab View
    private var allAlbumsSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Albums")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppleMusicTheme.label)
                .padding(.horizontal, 16)
            
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(searchVM.matchedAlbums) { album in
                    NavigationLink(value: AppRoute.album(album.id)) {
                        AlbumCard(album: album, size: 165)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - All Artists Tab View
    private var allArtistsSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Artists")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppleMusicTheme.label)
                .padding(.horizontal, 16)
            
            LazyVGrid(columns: gridColumns, spacing: 18) {
                ForEach(searchVM.matchedArtists) { artist in
                    NavigationLink(value: AppRoute.artist(artist.id)) {
                        ArtistCard(artist: artist, diameter: 140)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - All Playlists Tab View
    private var allPlaylistsSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Playlists")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppleMusicTheme.label)
                .padding(.horizontal, 16)
            
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(searchVM.matchedPlaylists) { pl in
                    NavigationLink(value: AppRoute.playlist(pl.id)) {
                        playlistCard(pl: pl, size: 165)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Reusable Playlist Card
    private func playlistCard(pl: Playlist, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let url = ImageHelper.highResArtworkURL(from: pl.artworkURL, resolution: .card) {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppleMusicTheme.subtleBorder, lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(pl.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppleMusicTheme.label)
                    .lineLimit(1)
                
                Text(pl.author ?? "Playlist")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppleMusicTheme.secondaryLabel)
                    .lineLimit(1)
            }
            .frame(width: size, alignment: .leading)
        }
    }
    
    // MARK: - Section Header with "See All >"
    private func sectionHeaderWithSeeAll(title: String, onSeeAll: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppleMusicTheme.label)
            
            Spacer()
            
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onSeeAll()
            } label: {
                HStack(spacing: 4) {
                    Text("See All")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppleMusicTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
}
