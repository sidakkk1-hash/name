import SwiftUI

// MARK: - SearchV (Apple Music Search Screen)
/// Reconstructed Search view with native search bar, 2-column vibrant Browse Categories,
/// recent searches, and categorized search results (Songs, Albums, Artists).
public struct SearchV: View {
    @Bindable public var searchVM: SearchVM = SearchVM.shared
    @Bindable public var player: PlayerEngine = .shared
    
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if searchVM.query.isEmpty {
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
                            
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(searchVM.categories) { category in
                                    CategoryCard(category: category) {
                                        searchVM.query = category.title
                                        searchVM.performSearch()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    } else {
                        // Live Search Results
                        VStack(alignment: .leading, spacing: 20) {
                            // Matching Songs
                            if !searchVM.searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Songs")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(AppleMusicTheme.label)
                                        .padding(.horizontal, 16)
                                    
                                    LazyVStack(spacing: 6) {
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
                            
                            // Matching Albums
                            if !searchVM.matchedAlbums.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Albums")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(AppleMusicTheme.label)
                                        .padding(.horizontal, 16)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 14) {
                                            ForEach(searchVM.matchedAlbums) { album in
                                                NavigationLink {
                                                    AlbumV(album: album)
                                                } label: {
                                                    AlbumCard(album: album, size: 150) {
                                                        // NavigationLink
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            // Matching Artists
                            if !searchVM.matchedArtists.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Artists")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(AppleMusicTheme.label)
                                        .padding(.horizontal, 16)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(searchVM.matchedArtists) { artist in
                                                NavigationLink {
                                                    ArtistV(artist: artist)
                                                } label: {
                                                    ArtistCard(artist: artist, diameter: 120) {
                                                        // NavigationLink
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            if searchVM.searchResults.isEmpty && searchVM.matchedAlbums.isEmpty && searchVM.matchedArtists.isEmpty {
                                if searchVM.isSearching {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(AppleMusicTheme.accent)
                                            .padding(.top, 40)
                                        Spacer()
                                    }
                                } else {
                                    ContentUnavailableView.search(text: searchVM.query)
                                        .padding(.top, 40)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 90) // Room for CompactPlayer
            }
            .navigationTitle("Search")
            .searchable(
                text: $searchVM.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Artists, Songs, Lyrics, and More"
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
            .onChange(of: searchVM.query) { _, _ in
                searchVM.fetchSuggestions()
                searchVM.performSearch()
            }
        }
    }
}
