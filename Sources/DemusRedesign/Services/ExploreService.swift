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
    
    // MARK: - Spam & Low-Quality Filter
    public static func isLowQualityOrSpam(title: String, artist: String) -> Bool {
        let t = title.lowercased()
        let a = artist.lowercased()
        let combined = "\(t) \(a)"
        
        let spamTokens = [
            "lumivox", "midnight gravity", "chasing after-images",
            "2026", "2025 ~", "top hits 2026", "best english songs",
            "non stop", "jukebox", "compilation", "audio jukebox",
            "dj mix", "full album songs", "remix 2025", "top 100 songs",
            "trending 20", "daily top", "top 100 videos", "casa tupka",
            "greatest hits - foo", "top 100 music"
        ]
        
        for token in spamTokens {
            if combined.contains(token) { return true }
        }
        
        return false
    }

    // MARK: - Fetch Real Home & Explore Content
    public func fetchExploreContent() async -> ExploreContent {
        var content = ExploreContent()
        let isLoggedIn = GoogleAccountManager.shared.isLoggedIn
        content.isPersonalized = isLoggedIn
        
        // 1. Fetch FEmusic_home if logged in
        if isLoggedIn {
            do {
                let body: [String: Any] = [
                    "context": HTTPClient.makeYTMContext(),
                    "browseId": "FEmusic_home"
                ]
                let json = try await client.postJSON(urlString: Endpoints.browse, body: body)
                let sections = parseHomeFeed(json: json, isPersonalized: true)
                if !sections.isEmpty {
                    content.personalizedSections = sections
                }
            } catch {
                print("[ExploreService] FEmusic_home fetch error:", error)
            }
        }
        
        // 2. Taste Personalization from User's Playback History
        let history = LibraryRepository.shared.history
        var userArtists: [String] = []
        for song in history {
            var a = song.artistName.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if a.contains(",") { a = a.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? a }
            if a.contains("&") { a = a.components(separatedBy: "&").first?.trimmingCharacters(in: .whitespaces) ?? a }
            if !a.isEmpty && a != "Unknown Artist" && a.count > 1 && !userArtists.contains(a) && !Self.isLowQualityOrSpam(title: "", artist: a) {
                userArtists.append(a)
            }
        }
        
        // 3. Concurrently fetch curated Playlists, Albums, Artists & Charts
        async let punjabiHitsTask = SearchService.shared.search(query: "Top Punjabi Hits 2024")
        async let globalHitsTask = SearchService.shared.search(query: "Global Top Hits")
        async let hipHopHitsTask = SearchService.shared.search(query: "Hip Hop Hits")
        async let rockHitsTask = SearchService.shared.search(query: "90s Alternative Rock Hits")
        async let popHitsTask = SearchService.shared.search(query: "Top Pop Hits")
        
        // Albums matching taste
        async let dripsterAlbumTask = SearchService.shared.searchAlbums(query: "Dripster Cheema Y")
        async let aujlaAlbumTask = SearchService.shared.searchAlbums(query: "Making Memories Karan Aujla")
        async let ghostAlbumTask = SearchService.shared.searchAlbums(query: "Ghost Diljit Dosanjh")
        async let shubhAlbumTask = SearchService.shared.searchAlbums(query: "Still Rollin Shubh")
        async let utopiaAlbumTask = SearchService.shared.searchAlbums(query: "UTOPIA Travis Scott")
        async let weekndAlbumTask = SearchService.shared.searchAlbums(query: "After Hours The Weeknd")
        
        // Top Artists matching taste
        async let cheemaArtistTask = SearchService.shared.searchArtists(query: "Cheema Y")
        async let aujlaArtistTask = SearchService.shared.searchArtists(query: "Karan Aujla")
        async let diljitArtistTask = SearchService.shared.searchArtists(query: "Diljit Dosanjh")
        async let sidhuArtistTask = SearchService.shared.searchArtists(query: "Sidhu Moose Wala")
        async let shubhArtistTask = SearchService.shared.searchArtists(query: "Shubh")
        async let apArtistTask = SearchService.shared.searchArtists(query: "AP Dhillon")
        async let weekndArtistTask = SearchService.shared.searchArtists(query: "The Weeknd")
        async let drakeArtistTask = SearchService.shared.searchArtists(query: "Drake")
        async let travisArtistTask = SearchService.shared.searchArtists(query: "Travis Scott")
        
        // Await all parallel queries
        let rawPunjabi = (try? await punjabiHitsTask) ?? []
        let rawGlobal = (try? await globalHitsTask) ?? []
        let rawHipHop = (try? await hipHopHitsTask) ?? []
        let rawRock = (try? await rockHitsTask) ?? []
        let rawPop = (try? await popHitsTask) ?? []
        
        let punjabiSongs = rawPunjabi.filter { !Self.isLowQualityOrSpam(title: $0.title, artist: $0.artistName) }
        let globalSongs = rawGlobal.filter { !Self.isLowQualityOrSpam(title: $0.title, artist: $0.artistName) }
        let hipHopSongs = rawHipHop.filter { !Self.isLowQualityOrSpam(title: $0.title, artist: $0.artistName) }
        let rockSongs = rawRock.filter { !Self.isLowQualityOrSpam(title: $0.title, artist: $0.artistName) }
        let popSongs = rawPop.filter { !Self.isLowQualityOrSpam(title: $0.title, artist: $0.artistName) }
        
        // Build History-driven personalized sections
        var personalizedHistorySections: [HomeSection] = []
        for artist in userArtists.prefix(2) {
            let cleanArtist = artist.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanArtist.count > 1 else { continue }
            if let artistSongs = try? await SearchService.shared.search(query: "\(cleanArtist) songs") {
                let clean = artistSongs.filter { !Self.isLowQualityOrSpam(title: $0.title, artist: $0.artistName) }
                if !clean.isEmpty {
                    personalizedHistorySections.append(HomeSection(
                        title: "More From \(cleanArtist)",
                        subtitle: "Because you recently listened to \(cleanArtist)",
                        songs: Array(clean.prefix(12)),
                        isPersonalized: true
                    ))
                }
            }
        }
        
        // Prepend personalized sections
        content.personalizedSections = personalizedHistorySections + content.personalizedSections
        
        // 4. Curated Flagship Featured Playlists
        var playlists: [Playlist] = []
        
        if !punjabiSongs.isEmpty {
            playlists.append(Playlist(
                id: "pl-punjabi-heat",
                title: "Punjabi Heat",
                descriptionText: "The hottest Punjabi bangers, hip-hop & desi drip.",
                artworkURL: punjabiSongs.first?.artworkURL,
                songs: punjabiSongs,
                isUserCreated: false
            ))
        }
        
        if !globalSongs.isEmpty {
            playlists.append(Playlist(
                id: "pl-todays-hits",
                title: "Today's Hits",
                descriptionText: "The biggest songs across the globe right now.",
                artworkURL: globalSongs.first?.artworkURL,
                songs: globalSongs,
                isUserCreated: false
            ))
        }
        
        if !hipHopSongs.isEmpty {
            playlists.append(Playlist(
                id: "pl-hiphop-essentials",
                title: "Hip-Hop Essentials",
                descriptionText: "Heavyweight beats, iconic bars & rap royalty.",
                artworkURL: hipHopSongs.first?.artworkURL,
                songs: hipHopSongs,
                isUserCreated: false
            ))
        }
        
        if !rockSongs.isEmpty {
            playlists.append(Playlist(
                id: "pl-rock-alternative",
                title: "Rock & Alternative",
                descriptionText: "Essential guitar anthems, grunge & alt-rock staples.",
                artworkURL: rockSongs.first?.artworkURL,
                songs: rockSongs,
                isUserCreated: false
            ))
        }
        
        if !popSongs.isEmpty {
            playlists.append(Playlist(
                id: "pl-alist-pop",
                title: "A-List Pop",
                descriptionText: "Chart-topping anthems from the world's biggest stars.",
                artworkURL: popSongs.first?.artworkURL,
                songs: popSongs,
                isUserCreated: false
            ))
        }
        
        content.featuredPlaylists = playlists
        
        // 5. Popular Songs (Filtered Chart Toppers)
        var combinedSongs: [Song] = []
        for song in (punjabiSongs.prefix(5) + globalSongs.prefix(5) + hipHopSongs.prefix(5)) {
            if !combinedSongs.contains(where: { $0.id == song.id }) {
                combinedSongs.append(song)
            }
        }
        content.topSongs = combinedSongs
        
        // 6. Curated New Release Albums
        var albumsList: [Album] = []
        let rawAlbumResults = [
            (try? await dripsterAlbumTask)?.first,
            (try? await aujlaAlbumTask)?.first,
            (try? await ghostAlbumTask)?.first,
            (try? await shubhAlbumTask)?.first,
            (try? await utopiaAlbumTask)?.first,
            (try? await weekndAlbumTask)?.first
        ]
        for alb in rawAlbumResults.compactMap({ $0 }) {
            if !albumsList.contains(where: { $0.id == alb.id || $0.title.lowercased() == alb.title.lowercased() }) {
                albumsList.append(alb)
            }
        }
        content.newAlbums = albumsList
        
        // 7. Curated Top Artists
        var artistsList: [Artist] = []
        let rawArtistResults = [
            (try? await cheemaArtistTask)?.first,
            (try? await aujlaArtistTask)?.first,
            (try? await diljitArtistTask)?.first,
            (try? await sidhuArtistTask)?.first,
            (try? await shubhArtistTask)?.first,
            (try? await apArtistTask)?.first,
            (try? await weekndArtistTask)?.first,
            (try? await drakeArtistTask)?.first,
            (try? await travisArtistTask)?.first
        ]
        for art in rawArtistResults.compactMap({ $0 }) {
            if !artistsList.contains(where: { $0.id == art.id || $0.name.lowercased() == art.name.lowercased() }) {
                artistsList.append(art)
            }
        }
        content.topArtists = artistsList
        
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
                if let titleRuns = (basicHeader["title"] as? [String: Any])?["runs"] as? [[String: Any]] {
                    let joined = titleRuns.compactMap { $0["text"] as? String }.joined()
                    var clean = joined.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if clean.count > 1 {
                        sectionTitle = clean
                    }
                }
                if let straplineRuns = (basicHeader["strapline"] as? [String: Any])?["runs"] as? [[String: Any]] {
                    let joined = straplineRuns.compactMap { $0["text"] as? String }.joined()
                    var clean = joined.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if clean.count > 1 {
                        sectionSubtitle = clean
                    }
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
        if Self.isLowQualityOrSpam(title: title, artist: artist) { return nil }
        
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
        
        if Self.isLowQualityOrSpam(title: title, artist: subtitle) { return nil }
        
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
