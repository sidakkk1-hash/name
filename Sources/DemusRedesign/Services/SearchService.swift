import Foundation

// MARK: - SearchService
/// Real search networking service querying YouTube Music Innertube API.
/// Returns categorized results with preserved browseEndpoint IDs for seamless navigation.
public final class SearchService: @unchecked Sendable {
    public static let shared = SearchService()
    
    private let client: HTTPClient
    
    public init(client: HTTPClient = .shared) {
        self.client = client
    }
    
    // MARK: - Search Result Container
    public struct SearchResponse: Sendable {
        public let topResults: [TopResultItem]
        public let songs: [Song]
        public let albums: [Album]
        public let artists: [Artist]
        public let playlists: [Playlist]
        
        public init(
            topResults: [TopResultItem] = [],
            songs: [Song] = [],
            albums: [Album] = [],
            artists: [Artist] = [],
            playlists: [Playlist] = []
        ) {
            self.topResults = topResults
            self.songs = songs
            self.albums = albums
            self.artists = artists
            self.playlists = playlists
        }
    }
    
    // MARK: - Multi-Category Search
    public func searchAll(query: String) async -> SearchResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SearchResponse() }
        
        async let generalTask = try? searchGeneral(query: trimmed)
        async let songsTask = try? search(query: trimmed, filter: .songs)
        async let albumsTask = try? searchAlbums(query: trimmed)
        async let artistsTask = try? searchArtists(query: trimmed)
        async let playlistsTask = try? searchPlaylists(query: trimmed)
        
        let general = await generalTask
        var songs = await songsTask ?? []
        var albums = await albumsTask ?? []
        var artists = await artistsTask ?? []
        var playlists = await playlistsTask ?? []
        var topResults: [TopResultItem] = general?.topResults ?? []
        
        // Merge general results if any
        if let general = general {
            for s in general.songs where !songs.contains(where: { $0.id == s.id }) {
                songs.insert(s, at: 0)
            }
            for a in general.albums where !albums.contains(where: { $0.id == a.id }) {
                albums.insert(a, at: 0)
            }
            for ar in general.artists where !artists.contains(where: { $0.id == ar.id }) {
                artists.insert(ar, at: 0)
            }
            for p in general.playlists where !playlists.contains(where: { $0.id == p.id }) {
                playlists.insert(p, at: 0)
            }
        }
        
        // Intelligent fallback if no top card was returned by API
        if topResults.isEmpty {
            let lower = trimmed.lowercased()
            if let exactArtist = artists.first(where: { $0.name.lowercased() == lower }) {
                topResults.append(.artist(exactArtist))
            } else if let exactAlbum = albums.first(where: { $0.title.lowercased() == lower }) {
                topResults.append(.album(exactAlbum))
            } else if let firstArtist = artists.first {
                topResults.append(.artist(firstArtist))
            } else if let firstSong = songs.first {
                topResults.append(.song(firstSong))
            }
        }
        
        return SearchResponse(
            topResults: topResults,
            songs: songs,
            albums: albums,
            artists: artists,
            playlists: playlists
        )
    }
    
    // MARK: - Search General (Unfiltered for Top Card and Mixed Items)
    public func searchGeneral(query: String) async throws -> SearchResponse {
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "query": query
        ]
        let json = try await client.postJSON(urlString: Endpoints.search, body: body)
        return parseGeneralSearch(json: json)
    }
    
    // MARK: - Search Songs (Direct Filtered Request)
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
    
    // MARK: - Search Playlists
    public func searchPlaylists(query: String) async throws -> [Playlist] {
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "query": query,
            "params": Endpoints.SearchFilter.playlists.rawValue
        ]
        let json = try await client.postJSON(urlString: Endpoints.search, body: body)
        return parsePlaylistsFromYTM(json: json)
    }
    
    // MARK: - Search Completions
    public func fetchSuggestions(for query: String) async -> [String] {
        guard let url = Endpoints.searchSuggestions(for: query) else { return [] }
        do {
            let data = try await client.get(url: url)
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
    
    // MARK: - General Search Parsing
    private func parseGeneralSearch(json: [String: Any]) -> SearchResponse {
        var topResults: [TopResultItem] = []
        var songs: [Song] = []
        var albums: [Album] = []
        var artists: [Artist] = []
        var playlists: [Playlist] = []
        
        guard let contents = json["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return SearchResponse()
        }
        
        for section in sectionContents {
            // Check for Top Card
            if let card = section["musicCardShelfRenderer"] as? [String: Any] {
                if let topItem = parseTopCard(card: card) {
                    topResults.append(topItem)
                }
                // Also parse top songs listed inside the card
                if let cardContents = card["contents"] as? [[String: Any]] {
                    for c in cardContents {
                        if let r = c["musicResponsiveListItemRenderer"] as? [String: Any],
                           let song = parseSingleSong(renderer: r) {
                            if !songs.contains(where: { $0.id == song.id }) {
                                songs.append(song)
                            }
                        }
                    }
                }
            }
            
            // Check for Shelves or ItemSections
            let shelf = section["musicShelfRenderer"] as? [String: Any]
            let shelfTitleRuns = (shelf?["title"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
            let shelfTitle = shelfTitleRuns.compactMap { $0["text"] as? String }.joined().lowercased()
            
            // Audio-only: ignore video shelves ("Videos", "Music videos", etc.)
            if shelfTitle.contains("video") {
                continue
            }
            
            let itemSec = section["itemSectionRenderer"] as? [String: Any]
            let items = (shelf?["contents"] as? [[String: Any]]) ?? (itemSec?["contents"] as? [[String: Any]]) ?? []
            
            for item in items {
                guard let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any] else { continue }
                
                // Categorize item based on its endpoints and columns
                let nav = renderer["navigationEndpoint"] as? [String: Any]
                let browse = nav?["browseEndpoint"] as? [String: Any]
                let pageType = ((browse?["browseEndpointContextSupportedConfigs"] as? [String: Any])?["browseEndpointContextMusicConfig"] as? [String: Any])?["pageType"] as? String
                let browseId = browse?["browseId"] as? String
                
                // Subtitle text fallback for categorization
                var subtitleText = ""
                if let flexCols = renderer["flexColumns"] as? [[String: Any]], flexCols.count > 1 {
                    let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                    let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                    subtitleText = runs1.compactMap { $0["text"] as? String }.joined(separator: " ").lowercased()
                }
                
                // Reject video-only items
                if subtitleText.hasPrefix("video") || subtitleText.contains("music video") || subtitleText.contains("shorts") {
                    continue
                }
                
                if pageType == "MUSIC_PAGE_TYPE_ARTIST" || (browseId?.hasPrefix("UC") == true) || subtitleText.contains("artist") {
                    if let artist = parseSingleArtist(renderer: renderer) {
                        artists.append(artist)
                    }
                } else if pageType == "MUSIC_PAGE_TYPE_ALBUM" || (browseId?.hasPrefix("MPRE") == true) || (browseId?.hasPrefix("OLAK") == true) || subtitleText.contains("album") || subtitleText.contains("single") || subtitleText.contains("ep") {
                    if let album = parseSingleAlbum(renderer: renderer) {
                        albums.append(album)
                    }
                } else if pageType == "MUSIC_PAGE_TYPE_PLAYLIST" || (browseId?.hasPrefix("VL") == true) || (browseId?.hasPrefix("PL") == true) || subtitleText.contains("playlist") {
                    if let pl = parseSinglePlaylist(renderer: renderer) {
                        playlists.append(pl)
                    }
                } else {
                    if let song = parseSingleSong(renderer: renderer) {
                        songs.append(song)
                    }
                }
            }
        }
        
        return SearchResponse(
            topResults: topResults,
            songs: songs,
            albums: albums,
            artists: artists,
            playlists: playlists
        )
    }
    
    // MARK: - Parse Top Result Card
    private func parseTopCard(card: [String: Any]) -> TopResultItem? {
        let titleRuns = (card["title"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
        let title = titleRuns.compactMap { $0["text"] as? String }.joined()
        guard !title.isEmpty else { return nil }
        
        let subRuns = (card["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
        let subtitle = subRuns.compactMap { $0["text"] as? String }.joined()
        
        var artworkURL: URL?
        if let thumb = card["thumbnail"] as? [String: Any] {
            let thumbsDict = (thumb["musicThumbnailRenderer"] as? [String: Any])?["thumbnail"] as? [String: Any] ?? thumb
            if let thumbs = thumbsDict["thumbnails"] as? [[String: Any]],
               let last = thumbs.last,
               let urlStr = last["url"] as? String {
                artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
            }
        }
        
        // Check navigation endpoint on card title run or card itself
        let titleNav = titleRuns.first?["navigationEndpoint"] as? [String: Any]
        let cardNav = card["navigationEndpoint"] as? [String: Any] ?? titleNav
        let browse = cardNav?["browseEndpoint"] as? [String: Any]
        let pageType = ((browse?["browseEndpointContextSupportedConfigs"] as? [String: Any])?["browseEndpointContextMusicConfig"] as? [String: Any])?["pageType"] as? String
        let browseId = browse?["browseId"] as? String
        
        // Artist card
        if pageType == "MUSIC_PAGE_TYPE_ARTIST" || subtitle.lowercased().contains("artist") || browseId?.hasPrefix("UC") == true {
            let artist = Artist(
                id: browseId ?? UUID().uuidString,
                name: title,
                artworkURL: artworkURL,
                subscribers: subtitle
            )
            return .artist(artist)
        }
        
        // Album card
        if pageType == "MUSIC_PAGE_TYPE_ALBUM" || subtitle.lowercased().contains("album") || subtitle.lowercased().contains("single") || subtitle.lowercased().contains("ep") {
            let album = Album(
                id: browseId ?? UUID().uuidString,
                title: title,
                artist: subtitle,
                artworkURL: artworkURL
            )
            return .album(album)
        }
        
        // Song / Audio card (Sanitize out any "Video" text)
        let watch = cardNav?["watchEndpoint"] as? [String: Any]
        if let videoId = watch?["videoId"] as? String, !videoId.isEmpty {
            var cleanArtist = subtitle
            if cleanArtist.lowercased().hasPrefix("video • ") {
                cleanArtist = String(cleanArtist.dropFirst(8))
            } else if cleanArtist.lowercased().hasPrefix("music video • ") {
                cleanArtist = String(cleanArtist.dropFirst(14))
            } else if cleanArtist.lowercased().hasPrefix("song • ") {
                cleanArtist = String(cleanArtist.dropFirst(7))
            }
            cleanArtist = cleanArtist.replacingOccurrences(of: "Video • ", with: "")
                .replacingOccurrences(of: "Music Video • ", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            let song = Song(
                id: videoId,
                title: title,
                artistName: cleanArtist.isEmpty ? "Artist" : cleanArtist,
                artworkURL: artworkURL
            )
            return .song(song)
        }
        
        // Playlist card
        if pageType == "MUSIC_PAGE_TYPE_PLAYLIST" || subtitle.lowercased().contains("playlist") {
            let pl = Playlist(
                id: browseId ?? UUID().uuidString,
                title: title,
                author: subtitle,
                artworkURL: artworkURL
            )
            return .playlist(pl)
        }
        
        return nil
    }
    
    // MARK: - Parse Single Song Helper
    private func parseSingleSong(renderer: [String: Any]) -> Song? {
        var title = "Unknown Title"
        var artist = "Unknown Artist"
        var artistId = ""
        var album: String?
        var albumId: String?
        var videoId = ""
        var duration: TimeInterval = 180
        var isExplicit = false
        
        if let badges = renderer["badges"] as? [[String: Any]] {
            for b in badges {
                if let badgeRenderer = b["musicInlineBadgeRenderer"] as? [String: Any],
                   let icon = badgeRenderer["icon"] as? [String: Any],
                   let iconType = icon["iconType"] as? String,
                   iconType.contains("EXPLICIT") {
                    isExplicit = true
                }
            }
        }
        
        if let flexCols = renderer["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
            // Col 0: Title & WatchEndpoint
            let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
            let runs0 = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
            if let first = runs0.first {
                title = first["text"] as? String ?? title
                let nav = first["navigationEndpoint"] as? [String: Any]
                let watch = nav?["watchEndpoint"] as? [String: Any]
                videoId = watch?["videoId"] as? String ?? ""
            }
            
            // Col 1: Artist, Album, Duration
            if flexCols.count > 1 {
                let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                
                for r in runs1 {
                    let text = r["text"] as? String ?? ""
                    let nav = r["navigationEndpoint"] as? [String: Any]
                    let browse = nav?["browseEndpoint"] as? [String: Any]
                    let bId = browse?["browseId"] as? String
                    let pType = ((browse?["browseEndpointContextSupportedConfigs"] as? [String: Any])?["browseEndpointContextMusicConfig"] as? [String: Any])?["pageType"] as? String
                    
                    let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
                    if lower == "video" || lower == "music video" || lower == "ugc" || lower == "short" {
                        // Never accept Video as artist name
                        continue
                    }
                    
                    if pType == "MUSIC_PAGE_TYPE_ARTIST" || (bId?.hasPrefix("UC") == true) {
                        artist = text
                        artistId = bId ?? ""
                    } else if pType == "MUSIC_PAGE_TYPE_ALBUM" || (bId?.hasPrefix("MPRE") == true) || (bId?.hasPrefix("OLAK") == true) {
                        album = text
                        albumId = bId
                    } else if text.contains(":") {
                        duration = parseDuration(text)
                    } else if artist == "Unknown Artist" && !text.trimmingCharacters(in: .whitespaces).isEmpty && text != "•" && text != "Song" && lower != "video" {
                        artist = text
                    }
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
        
        guard !videoId.isEmpty else { return nil }
        
        var artworkURL: URL?
        if let thumbRenderer = renderer["thumbnail"] as? [String: Any],
           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr), videoId: videoId)
        }
        
        return Song(
            id: videoId,
            title: title,
            artistId: artistId.isEmpty ? "artist-\(artist)" : artistId,
            artistBrowseId: artistId.isEmpty ? nil : artistId,
            artistName: artist,
            albumId: albumId,
            albumBrowseId: albumId,
            albumTitle: album,
            artworkURL: artworkURL,
            duration: duration,
            isExplicit: isExplicit
        )
    }
    
    // MARK: - Parse Single Album Helper
    private func parseSingleAlbum(renderer: [String: Any]) -> Album? {
        var title = "Unknown Album"
        var artist = "Unknown Artist"
        var artistId: String?
        var albumId = ""
        var artworkURL: URL?
        var year: String?
        var albumType = "Album"
        
        // Check browseId from renderer top navigationEndpoint
        if let nav = renderer["navigationEndpoint"] as? [String: Any],
           let browse = nav["browseEndpoint"] as? [String: Any],
           let bId = browse["browseId"] as? String {
            albumId = bId
        }
        
        if let flexCols = renderer["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
            // Col 0: Album Title & NavigationEndpoint
            let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
            let runs0 = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
            if let first = runs0.first {
                title = first["text"] as? String ?? title
                if albumId.isEmpty,
                   let nav = first["navigationEndpoint"] as? [String: Any],
                   let browse = nav["browseEndpoint"] as? [String: Any],
                   let bId = browse["browseId"] as? String {
                    albumId = bId
                }
            }
            
            // Col 1: Type • Artist • Year
            if flexCols.count > 1 {
                let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                for r in runs1 {
                    let text = r["text"] as? String ?? ""
                    let nav = r["navigationEndpoint"] as? [String: Any]
                    let browse = nav?["browseEndpoint"] as? [String: Any]
                    let bId = browse?["browseId"] as? String
                    
                    if let bId = bId, bId.hasPrefix("UC") {
                        artist = text
                        artistId = bId
                    } else if text == "Album" || text == "Single" || text == "EP" {
                        albumType = text
                    } else if text.count == 4 && Int(text) != nil {
                        year = text
                    } else if artist == "Unknown Artist" && !text.trimmingCharacters(in: .whitespaces).isEmpty && text != "•" {
                        artist = text
                    }
                }
            }
        }
        
        guard !albumId.isEmpty else { return nil }
        
        if let thumbRenderer = renderer["thumbnail"] as? [String: Any],
           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
        }
        
        return Album(
            id: albumId,
            title: title,
            artist: artist,
            artistName: artist,
            artistId: artistId,
            artistBrowseId: artistId,
            artworkURL: artworkURL,
            year: year,
            albumType: albumType
        )
    }
    
    // MARK: - Parse Single Artist Helper
    private func parseSingleArtist(renderer: [String: Any]) -> Artist? {
        var name = "Unknown Artist"
        var artistId = ""
        var artworkURL: URL?
        var subscribers: String?
        
        if let nav = renderer["navigationEndpoint"] as? [String: Any],
           let browse = nav["browseEndpoint"] as? [String: Any],
           let bId = browse["browseId"] as? String {
            artistId = bId
        }
        
        if let flexCols = renderer["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
            let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
            let runs0 = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
            if let first = runs0.first {
                name = first["text"] as? String ?? name
                if artistId.isEmpty,
                   let nav = first["navigationEndpoint"] as? [String: Any],
                   let browse = nav["browseEndpoint"] as? [String: Any],
                   let bId = browse["browseId"] as? String {
                    artistId = bId
                }
            }
            if flexCols.count > 1 {
                let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                subscribers = runs1.compactMap { $0["text"] as? String }.joined()
            }
        }
        
        guard !artistId.isEmpty else { return nil }
        
        if let thumbRenderer = renderer["thumbnail"] as? [String: Any],
           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
        }
        
        return Artist(
            id: artistId,
            name: name,
            artworkURL: artworkURL,
            subscribers: subscribers
        )
    }
    
    // MARK: - Parse Single Playlist Helper
    private func parseSinglePlaylist(renderer: [String: Any]) -> Playlist? {
        var title = "Unknown Playlist"
        var author: String?
        var playlistId = ""
        var artworkURL: URL?
        
        if let nav = renderer["navigationEndpoint"] as? [String: Any],
           let browse = nav["browseEndpoint"] as? [String: Any],
           let bId = browse["browseId"] as? String {
            playlistId = bId
        }
        
        if let flexCols = renderer["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
            let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
            let runs0 = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
            if let first = runs0.first {
                title = first["text"] as? String ?? title
                if playlistId.isEmpty,
                   let nav = first["navigationEndpoint"] as? [String: Any],
                   let browse = nav["browseEndpoint"] as? [String: Any],
                   let bId = browse["browseId"] as? String {
                    playlistId = bId
                }
            }
            if flexCols.count > 1 {
                let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                author = runs1.compactMap { $0["text"] as? String }.joined()
            }
        }
        
        guard !playlistId.isEmpty else { return nil }
        
        if let thumbRenderer = renderer["thumbnail"] as? [String: Any],
           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
        }
        
        return Playlist(
            id: playlistId,
            title: title,
            author: author,
            artworkURL: artworkURL
        )
    }
    
    // MARK: - Parsing Songs Array
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
            let shelf = section["musicShelfRenderer"] as? [String: Any] ?? section["itemSectionRenderer"] as? [String: Any]
            guard let items = shelf?["contents"] as? [[String: Any]] else { continue }
            for item in items {
                if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                   let song = parseSingleSong(renderer: renderer) {
                    songs.append(song)
                }
            }
        }
        return songs
    }
    
    // MARK: - Parsing Albums Array
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
            let shelf = section["musicShelfRenderer"] as? [String: Any] ?? section["itemSectionRenderer"] as? [String: Any]
            guard let items = shelf?["contents"] as? [[String: Any]] else { continue }
            for item in items {
                if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                   let album = parseSingleAlbum(renderer: renderer) {
                    albums.append(album)
                }
            }
        }
        return albums
    }
    
    // MARK: - Parsing Artists Array
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
            let shelf = section["musicShelfRenderer"] as? [String: Any] ?? section["itemSectionRenderer"] as? [String: Any]
            guard let items = shelf?["contents"] as? [[String: Any]] else { continue }
            for item in items {
                if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                   let artist = parseSingleArtist(renderer: renderer) {
                    artists.append(artist)
                }
            }
        }
        return artists
    }
    
    // MARK: - Parsing Playlists Array
    private func parsePlaylistsFromYTM(json: [String: Any]) -> [Playlist] {
        var playlists: [Playlist] = []
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
            let shelf = section["musicShelfRenderer"] as? [String: Any] ?? section["itemSectionRenderer"] as? [String: Any]
            guard let items = shelf?["contents"] as? [[String: Any]] else { continue }
            for item in items {
                if let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                   let playlist = parseSinglePlaylist(renderer: renderer) {
                    playlists.append(playlist)
                }
            }
        }
        return playlists
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
