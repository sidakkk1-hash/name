import Foundation

// MARK: - ExploreService
/// Real charts, trending, and popular music service querying YouTube Music browse endpoints.
public final class ExploreService: @unchecked Sendable {
    public static let shared = ExploreService()
    
    private let client: HTTPClient
    
    public init(client: HTTPClient = .shared) {
        self.client = client
    }
    
    // MARK: - Explore Content Model
    public struct ExploreContent: Sendable {
        public var topSongs: [Song]
        public var newAlbums: [Album]
        public var topArtists: [Artist]
        public var featuredPlaylists: [Playlist]
        
        public init(
            topSongs: [Song] = [],
            newAlbums: [Album] = [],
            topArtists: [Artist] = [],
            featuredPlaylists: [Playlist] = []
        ) {
            self.topSongs = topSongs
            self.newAlbums = newAlbums
            self.topArtists = topArtists
            self.featuredPlaylists = featuredPlaylists
        }
    }
    
    // MARK: - Fetch Real Charts & Explore Content
    public func fetchExploreContent() async -> ExploreContent {
        var content = ExploreContent()
        
        do {
            // 1. Fetch Charts Browse
            let body: [String: Any] = [
                "context": HTTPClient.makeYTMContext(),
                "browseId": "FEmusic_charts"
            ]
            let json = try await client.postJSON(urlString: Endpoints.browse, body: body)
            let (songs, artists) = parseCharts(json: json)
            content.topSongs = songs
            content.topArtists = artists
        } catch {
            // Silently continue
        }
        
        // If songs empty, query fallback top charts search
        if content.topSongs.isEmpty {
            if let searchSongs = try? await SearchService.shared.search(query: "Top Global Hits 2026") {
                content.topSongs = Array(searchSongs.prefix(15))
            }
        }
        
        // Fetch Top Albums
        if let albums = try? await SearchService.shared.searchAlbums(query: "Top Hits Albums") {
            content.newAlbums = Array(albums.prefix(10))
        }
        
        // Fetch Featured Playlists
        content.featuredPlaylists = [
            Playlist(
                id: "pl-today-hits",
                title: "Today's Hits",
                descriptionText: "The biggest songs right now.",
                artworkURL: content.topSongs.first?.artworkURL,
                songs: content.topSongs,
                isUserCreated: false
            )
        ]
        
        return content
    }
    
    // MARK: - Parsing Charts Response
    private func parseCharts(json: [String: Any]) -> ([Song], [Artist]) {
        var songs: [Song] = []
        var artists: [Artist] = []
        
        guard let contents = json["contents"] as? [String: Any],
              let singleCol = contents["singleColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = singleCol["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sections = sectionList["contents"] as? [[String: Any]] else {
            return (songs, artists)
        }
        
        for section in sections {
            let carousel = section["musicCarouselShelfRenderer"] as? [String: Any]
            guard let items = carousel?["contents"] as? [[String: Any]] else { continue }
            
            for item in items {
                // Parse songs (musicResponsiveListItemRenderer)
                if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any] {
                    var title = "Unknown Title"
                    var artist = "Unknown Artist"
                    var videoId = ""
                    
                    if let flexCols = renderer["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
                        let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                        let runs = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                        if let first = runs.first {
                            title = first["text"] as? String ?? title
                            let nav = first["navigationEndpoint"] as? [String: Any]
                            let watch = nav?["watchEndpoint"] as? [String: Any]
                            videoId = watch?["videoId"] as? String ?? ""
                        }
                        if flexCols.count > 1 {
                            let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                            let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                            if !runs1.isEmpty {
                                artist = runs1[0]["text"] as? String ?? artist
                            }
                        }
                    }
                    
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
                        songs.append(Song(
                            id: videoId,
                            title: title,
                            artistName: artist,
                            artworkURL: artworkURL
                        ))
                    }
                }
                
                // Parse artists / albums (musicTwoRowItemRenderer)
                if let twoRow = item["musicTwoRowItemRenderer"] as? [String: Any] {
                    var title = "Unknown"
                    if let titleRuns = (twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                        title = first["text"] as? String ?? title
                    }
                    var artworkURL: URL?
                    if let thumbRenderer = twoRow["thumbnailRenderer"] as? [String: Any],
                       let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
                       let thumbnail = musicThumb["thumbnail"] as? [String: Any],
                       let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
                       let last = thumbs.last,
                       let urlStr = last["url"] as? String {
                        artworkURL = URL(string: urlStr)
                    }
                    
                    artists.append(Artist(name: title, artworkURL: artworkURL))
                }
            }
        }
        
        return (songs, artists)
    }
}
