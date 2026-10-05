import Foundation

// MARK: - SearchService
/// Real search networking service querying YouTube Music Innertube API.
public final class SearchService: @unchecked Sendable {
    public static let shared = SearchService()
    
    private let client: HTTPClient
    
    public init(client: HTTPClient = .shared) {
        self.client = client
    }
    
    // MARK: - Search Result Container
    public struct SearchResponse: Sendable {
        public let songs: [Song]
        public let albums: [Album]
        public let artists: [Artist]
        public let playlists: [Playlist]
        
        public init(songs: [Song] = [], albums: [Album] = [], artists: [Artist] = [], playlists: [Playlist] = []) {
            self.songs = songs
            self.albums = albums
            self.artists = artists
            self.playlists = playlists
        }
    }
    
    // MARK: - Search Songs (Direct Innertube Request)
    public func search(query: String, filter: Endpoints.SearchFilter = .songs) async throws -> [Song] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "query": trimmed,
            "params": filter.rawValue
        ]
        
        let json = try await client.postJSON(urlString: Endpoints.search, body: body)
        return parseSongsFromYTM(json: json)
    }
    
    // MARK: - Multi-Category Search
    public func searchAll(query: String) async -> SearchResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SearchResponse() }
        
        async let songsTask = try? search(query: trimmed, filter: .songs)
        async let albumsTask = try? searchAlbums(query: trimmed)
        async let artistsTask = try? searchArtists(query: trimmed)
        
        let songs = await songsTask ?? []
        let albums = await albumsTask ?? []
        let artists = await artistsTask ?? []
        
        return SearchResponse(songs: songs, albums: albums, artists: artists, playlists: [])
    }
    
    // MARK: - Search Albums
    public func searchAlbums(query: String) async throws -> [Album] {
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "query": query,
            "params": Endpoints.SearchFilter.albums.rawValue
        ]
        let json = try await client.postJSON(urlString: Endpoints.search, body: body)
        return parseAlbumsFromYTM(json: json)
    }
    
    // MARK: - Search Artists
    public func searchArtists(query: String) async throws -> [Artist] {
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "query": query,
            "params": Endpoints.SearchFilter.artists.rawValue
        ]
        let json = try await client.postJSON(urlString: Endpoints.search, body: body)
        return parseArtistsFromYTM(json: json)
    }
    
    // MARK: - Search Completions
    public func fetchSuggestions(for query: String) async -> [String] {
        guard let url = Endpoints.searchSuggestions(for: query) else { return [] }
        do {
            let data = try await client.get(url: url)
            // Format is jsonp: window.google.ac.h(["query", [["suggestion1", 0], ["suggestion2", 0]]])
            if let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                if let startIdx = string.firstIndex(of: "("), let endIdx = string.lastIndex(of: ")") {
                    let jsonSub = string[string.index(after: startIdx)..<endIdx]
                    if let rawArray = try? JSONSerialization.jsonObject(with: Data(jsonSub.utf8), options: []) as? [Any],
                       rawArray.count > 1,
                       let suggestions = rawArray[1] as? [[Any]] {
                        return suggestions.compactMap { $0.first as? String }
                    }
                }
            }
        } catch {
            // Silently fallback on network error
        }
        return []
    }
    
    // MARK: - Parsing Helpers
    private func parseSongsFromYTM(json: [String: Any]) -> [Song] {
        var songs: [Song] = []
        
        guard let contents = json["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }
        
        for section in sectionContents {
            let shelf = section["musicShelfRenderer"] as? [String: Any] ?? section["musicCardShelfRenderer"] as? [String: Any]
            guard let shelf = shelf, let items = shelf["contents"] as? [[String: Any]] else { continue }
            
            for item in items {
                guard let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any] else { continue }
                
                var title = "Unknown Title"
                var artist = "Unknown Artist"
                var album: String?
                var videoId = ""
                var duration: TimeInterval = 180
                
                // Flex Column 0: Title & WatchEndpoint
                if let flexCols = renderer["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
                    let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                    let runs = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                    if let firstRun = runs.first {
                        title = firstRun["text"] as? String ?? title
                        let nav = firstRun["navigationEndpoint"] as? [String: Any]
                        let watch = nav?["watchEndpoint"] as? [String: Any]
                        videoId = watch?["videoId"] as? String ?? ""
                    }
                    
                    // Flex Column 1: Artist, Album, Duration
                    if flexCols.count > 1 {
                        let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                        let col1Runs = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                        if !col1Runs.isEmpty {
                            artist = col1Runs[0]["text"] as? String ?? artist
                        }
                        if col1Runs.count >= 3 {
                            album = col1Runs[2]["text"] as? String
                        }
                        if let lastRun = col1Runs.last, let durStr = lastRun["text"] as? String, durStr.contains(":") {
                            duration = parseDuration(durStr)
                        }
                    }
                }
                
                // Fallback for videoId from overlay play button
                if videoId.isEmpty {
                    if let overlay = renderer["overlay"] as? [String: Any],
                       let thumbOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
                       let content = thumbOverlay["content"] as? [String: Any],
                       let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
                       let playNav = playBtn["playNavigationEndpoint"] as? [String: Any],
                       let watch = playNav["watchEndpoint"] as? [String: Any] {
                        videoId = watch["videoId"] as? String ?? ""
                    }
                }
                
                // Thumbnails
                var artworkURL: URL?
                if let thumbRenderer = renderer["thumbnail"] as? [String: Any],
                   let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
                   let thumbnail = musicThumb["thumbnail"] as? [String: Any],
                   let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
                   let last = thumbs.last,
                   let urlStr = last["url"] as? String {
                    artworkURL = URL(string: urlStr)
                }
                
                if !videoId.isEmpty {
                    let song = Song(
                        id: videoId,
                        title: title,
                        artistId: "artist-\(artist)",
                        artistName: artist,
                        albumTitle: album,
                        artworkURL: artworkURL,
                        duration: duration
                    )
                    songs.append(song)
                }
            }
        }
        
        return songs
    }
    
    private func parseAlbumsFromYTM(json: [String: Any]) -> [Album] {
        var albums: [Album] = []
        guard let contents = json["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }
        
        for section in sectionContents {
            guard let shelf = section["musicShelfRenderer"] as? [String: Any],
                  let items = shelf["contents"] as? [[String: Any]] else { continue }
            
            for item in items {
                guard let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any] else { continue }
                var title = "Unknown Album"
                var artist = "Unknown Artist"
                var artworkURL: URL?
                var albumId = UUID().uuidString
                
                if let flexCols = renderer["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
                    let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                    let runs = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                    if let first = runs.first {
                        title = first["text"] as? String ?? title
                        if let nav = first["navigationEndpoint"] as? [String: Any],
                           let browse = nav["browseEndpoint"] as? [String: Any],
                           let bId = browse["browseId"] as? String {
                            albumId = bId
                        }
                    }
                    if flexCols.count > 1 {
                        let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                        let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                        if runs1.count >= 2 {
                            artist = runs1[1]["text"] as? String ?? artist
                        }
                    }
                }
                
                if let thumbRenderer = renderer["thumbnail"] as? [String: Any],
                   let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
                   let thumbnail = musicThumb["thumbnail"] as? [String: Any],
                   let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
                   let last = thumbs.last,
                   let urlStr = last["url"] as? String {
                    artworkURL = URL(string: urlStr)
                }
                
                albums.append(Album(id: albumId, title: title, artist: artist, artworkURL: artworkURL))
            }
        }
        return albums
    }
    
    private func parseArtistsFromYTM(json: [String: Any]) -> [Artist] {
        var artists: [Artist] = []
        guard let contents = json["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }
        
        for section in sectionContents {
            guard let shelf = section["musicShelfRenderer"] as? [String: Any],
                  let items = shelf["contents"] as? [[String: Any]] else { continue }
            
            for item in items {
                guard let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any] else { continue }
                var name = "Unknown Artist"
                var artistId = UUID().uuidString
                var artworkURL: URL?
                
                if let flexCols = renderer["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
                    let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                    let runs = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                    if let first = runs.first {
                        name = first["text"] as? String ?? name
                        if let nav = first["navigationEndpoint"] as? [String: Any],
                           let browse = nav["browseEndpoint"] as? [String: Any],
                           let bId = browse["browseId"] as? String {
                            artistId = bId
                        }
                    }
                }
                
                if let thumbRenderer = renderer["thumbnail"] as? [String: Any],
                   let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
                   let thumbnail = musicThumb["thumbnail"] as? [String: Any],
                   let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
                   let last = thumbs.last,
                   let urlStr = last["url"] as? String {
                    artworkURL = URL(string: urlStr)
                }
                
                artists.append(Artist(id: artistId, name: name, artworkURL: artworkURL))
            }
        }
        return artists
    }
    
    private func parseDuration(_ string: String) -> TimeInterval {
        let parts = string.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return 180
    }
}
