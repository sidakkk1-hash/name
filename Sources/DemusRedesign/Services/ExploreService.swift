import Foundation

// MARK: - HomeSection
public struct HomeSection: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let subtitle: String?
    public let songs: [Song]
    public let isPersonalized: Bool
    
    public init(title: String, subtitle: String? = nil, songs: [Song], isPersonalized: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.songs = songs
        self.isPersonalized = isPersonalized
    }
}

// MARK: - ExploreService
/// Real charts, personalized home feed, and trending music service querying YouTube Music browse endpoints.
public final class ExploreService: @unchecked Sendable {
    public static let shared = ExploreService()
    
    private let client: HTTPClient
    
    public init(client: HTTPClient = .shared) {
        self.client = client
    }
    
    // MARK: - Explore Content Model
    public struct ExploreContent: Sendable {
        public var personalizedSections: [HomeSection]
        public var topSongs: [Song]
        public var newAlbums: [Album]
        public var topArtists: [Artist]
        public var featuredPlaylists: [Playlist]
        public var isPersonalized: Bool
        
        public init(
            personalizedSections: [HomeSection] = [],
            topSongs: [Song] = [],
            newAlbums: [Album] = [],
            topArtists: [Artist] = [],
            featuredPlaylists: [Playlist] = [],
            isPersonalized: Bool = false
        ) {
            self.personalizedSections = personalizedSections
            self.topSongs = topSongs
            self.newAlbums = newAlbums
            self.topArtists = topArtists
            self.featuredPlaylists = featuredPlaylists
            self.isPersonalized = isPersonalized
        }
    }
    
    // MARK: - Fetch Real Home & Explore Content
    public func fetchExploreContent() async -> ExploreContent {
        var content = ExploreContent()
        let isLoggedIn = GoogleAccountManager.shared.isLoggedIn
        content.isPersonalized = isLoggedIn
        
        // 1. Fetch FEmusic_home (Personalized feed when logged in, or curated home feed)
        do {
            let body: [String: Any] = [
                "context": HTTPClient.makeYTMContext(),
                "browseId": "FEmusic_home"
            ]
            let json = try await client.postJSON(urlString: Endpoints.browse, body: body)
            let sections = parseHomeFeed(json: json, isPersonalized: isLoggedIn)
            if !sections.isEmpty {
                content.personalizedSections = sections
                if let firstSection = sections.first {
                    content.topSongs = firstSection.songs
                }
            }
        } catch {
            print("[ExploreService] FEmusic_home fetch error:", error)
        }
        
        // 2. Fetch Charts as well for trending songs & artists
        if content.topSongs.isEmpty || content.topArtists.isEmpty {
            do {
                let body: [String: Any] = [
                    "context": HTTPClient.makeYTMContext(),
                    "browseId": "FEmusic_charts"
                ]
                let json = try await client.postJSON(urlString: Endpoints.browse, body: body)
                let (chartsSongs, artists) = parseCharts(json: json)
                if content.topSongs.isEmpty {
                    content.topSongs = chartsSongs
                }
                content.topArtists = artists
            } catch {}
        }
        
        // 3. Fallback search if still empty
        if content.topSongs.isEmpty {
            if let searchSongs = try? await SearchService.shared.search(query: "Top Global Hits 2026") {
                content.topSongs = Array(searchSongs.prefix(15))
            }
        }
        
        // 4. Fetch Top Albums
        if let albums = try? await SearchService.shared.searchAlbums(query: "Top Hits Albums") {
            content.newAlbums = Array(albums.prefix(10))
        }
        
        // 5. Featured Playlists
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
    
    // MARK: - Parsing FEmusic_home Feed
    private func parseHomeFeed(json: [String: Any], isPersonalized: Bool) -> [HomeSection] {
        var sectionsResult: [HomeSection] = []
        
        guard let contents = json["contents"] as? [String: Any],
              let singleCol = contents["singleColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = singleCol["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sections = sectionList["contents"] as? [[String: Any]] else {
            return []
        }
        
        for section in sections {
            let carousel = section["musicCarouselShelfRenderer"] as? [String: Any]
            guard let shelf = carousel else { continue }
            
            // Extract section header title
            var sectionTitle = "Recommended For You"
            var sectionSubtitle: String?
            
            if let header = shelf["header"] as? [String: Any],
               let basicHeader = header["musicCarouselShelfBasicHeaderRenderer"] as? [String: Any] {
                if let titleRuns = (basicHeader["title"] as? [String: Any])?["runs"] as? [[String: Any]],
                   let first = titleRuns.first {
                    sectionTitle = first["text"] as? String ?? sectionTitle
                }
                if let straplineRuns = (basicHeader["strapline"] as? [String: Any])?["runs"] as? [[String: Any]],
                   let first = straplineRuns.first {
                    sectionSubtitle = first["text"] as? String
                }
            }
            
            guard let items = shelf["contents"] as? [[String: Any]] else { continue }
            var songs: [Song] = []
            
            for item in items {
                if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let song = parseSongItem(renderer: renderer) {
                        songs.append(song)
                    }
                } else if let twoRow = item["musicTwoRowItemRenderer"] as? [String: Any] {
                    // Extract song or item from twoRow
                    if let song = parseTwoRowSong(twoRow: twoRow) {
                        songs.append(song)
                    }
                }
            }
            
            if !songs.isEmpty {
                sectionsResult.append(HomeSection(
                    title: sectionTitle,
                    subtitle: sectionSubtitle,
                    songs: songs,
                    isPersonalized: isPersonalized
                ))
            }
        }
        
        return sectionsResult
    }
    
    private func parseSongItem(renderer: [String: Any]) -> Song? {
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
        
        guard !videoId.isEmpty else { return nil }
        
        var artworkURL: URL?
        if let thumbRenderer = renderer["thumbnail"] as? [String: Any],
           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr), videoId: videoId, resolution: .card)
        }
        
        return Song(id: videoId, title: title, artistName: artist, artworkURL: artworkURL)
    }
    
    private func parseTwoRowSong(twoRow: [String: Any]) -> Song? {
        var title = "Unknown"
        if let titleRuns = (twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
            title = first["text"] as? String ?? title
        }
        var subtitle = "Music"
        if let subRuns = (twoRow["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]], let first = subRuns.first {
            subtitle = first["text"] as? String ?? subtitle
        }
        
        var videoId = ""
        if let nav = twoRow["navigationEndpoint"] as? [String: Any] {
            if let watch = nav["watchEndpoint"] as? [String: Any] {
                videoId = watch["videoId"] as? String ?? ""
            }
        }
        
        guard !videoId.isEmpty else { return nil }
        
        var artworkURL: URL?
        if let thumbRenderer = twoRow["thumbnailRenderer"] as? [String: Any],
           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr), videoId: videoId, resolution: .card)
        }
        
        return Song(id: videoId, title: title, artistName: subtitle, artworkURL: artworkURL)
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
                if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let song = parseSongItem(renderer: renderer) {
                        songs.append(song)
                    }
                }
                
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
                        artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr), resolution: .card)
                    }
                    artists.append(Artist(name: title, artworkURL: artworkURL))
                }
            }
        }
        
        return (songs, artists)
    }
}
