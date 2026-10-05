import Foundation

// MARK: - BrowseService
/// Real service querying YouTube Music browse endpoint for full Albums, Artists, and Playlists.
public final class BrowseService: @unchecked Sendable {
    public static let shared = BrowseService()
    
    private let client: HTTPClient
    
    public init(client: HTTPClient = .shared) {
        self.client = client
    }
    
    // MARK: - Fetch Real Album Details & Tracklist
    public func fetchAlbum(id: String) async -> Album? {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return nil }
        
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "browseId": cleanId
        ]
        
        do {
            let json = try await client.postJSON(urlString: Endpoints.browse, body: body)
            return parseAlbumBrowse(id: cleanId, json: json)
        } catch {
            return nil
        }
    }
    
    // MARK: - Fetch Real Artist Profile & Discography
    public func fetchArtist(id: String) async -> Artist? {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return nil }
        
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "browseId": cleanId
        ]
        
        do {
            let json = try await client.postJSON(urlString: Endpoints.browse, body: body)
            return parseArtistBrowse(id: cleanId, json: json)
        } catch {
            return nil
        }
    }
    
    // MARK: - Fetch Real Playlist Details
    public func fetchPlaylist(id: String) async -> Playlist? {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return nil }
        
        let browseId = cleanId.hasPrefix("VL") ? cleanId : "VL\(cleanId)"
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "browseId": browseId
        ]
        
        do {
            let json = try await client.postJSON(urlString: Endpoints.browse, body: body)
            return parsePlaylistBrowse(id: cleanId, json: json)
        } catch {
            return nil
        }
    }
    
    // MARK: - Parsing Album Browse Response
    private func parseAlbumBrowse(id: String, json: [String: Any]) -> Album {
        var title = "Album"
        var artist = "Artist"
        var artistId: String?
        var artworkURL: URL?
        var releaseDate: String?
        var year: String?
        var albumType = "Album"
        var descriptionText: String?
        var songs: [Song] = []
        
        // 1. Check twoColumn tabs header for musicResponsiveHeaderRenderer
        if let twoCol = (json["contents"] as? [String: Any])?["twoColumnBrowseResultsRenderer"] as? [String: Any],
           let tabs = twoCol["tabs"] as? [[String: Any]],
           let firstTab = tabs.first,
           let tabContent = (firstTab["tabRenderer"] as? [String: Any])?["content"] as? [String: Any],
           let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
           let contents = sectionList["contents"] as? [[String: Any]],
           let firstSec = contents.first,
           let responsiveHeader = firstSec["musicResponsiveHeaderRenderer"] as? [String: Any] {
            
            if let titleRuns = (responsiveHeader["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                title = first["text"] as? String ?? title
            }
            
            // Strapline often has the artist name + artist browseId
            if let strapline = (responsiveHeader["straplineTextOne"] as? [String: Any])?["runs"] as? [[String: Any]], let first = strapline.first {
                artist = first["text"] as? String ?? artist
                let nav = first["navigationEndpoint"] as? [String: Any]
                let browse = nav?["browseEndpoint"] as? [String: Any]
                artistId = browse?["browseId"] as? String
            }
            
            // Subtitle runs: type, bullet, year
            if let subtitleRuns = (responsiveHeader["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                for r in subtitleRuns {
                    let text = r["text"] as? String ?? ""
                    if text == "Album" || text == "Single" || text == "EP" {
                        albumType = text
                    } else if text.count == 4 && Int(text) != nil {
                        year = text
                        releaseDate = text
                    }
                }
            }
            
            if let descRuns = (responsiveHeader["description"] as? [String: Any])?["runs"] as? [[String: Any]], let first = descRuns.first {
                descriptionText = first["text"] as? String
            }
            
            if let thumbRenderer = responsiveHeader["thumbnail"] as? [String: Any],
               let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
               let thumbnail = musicThumb["thumbnail"] as? [String: Any],
               let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
               let last = thumbs.last,
               let urlStr = last["url"] as? String {
                artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
            }
        }
        
        // 2. Fallback: DetailHeader
        let header = json["header"] as? [String: Any]
        if let detailHeader = header?["musicDetailHeaderRenderer"] as? [String: Any] {
            if let titleRuns = (detailHeader["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                title = first["text"] as? String ?? title
            }
            if let subtitleRuns = (detailHeader["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                for r in subtitleRuns {
                    let text = r["text"] as? String ?? ""
                    let nav = r["navigationEndpoint"] as? [String: Any]
                    let browse = nav?["browseEndpoint"] as? [String: Any]
                    if let bId = browse?["browseId"] as? String, bId.hasPrefix("UC") {
                        artist = text
                        artistId = bId
                    } else if text.count == 4 && Int(text) != nil {
                        year = text
                        releaseDate = text
                    }
                }
            }
            if let secondSub = (detailHeader["secondSubtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                let text = secondSub.compactMap { $0["text"] as? String }.joined()
                if !text.isEmpty {
                    releaseDate = (releaseDate != nil) ? "\(releaseDate!) • \(text)" : text
                }
            }
            if artworkURL == nil,
               let thumbRenderer = detailHeader["thumbnail"] as? [String: Any],
               let cropped = thumbRenderer["croppedSquareThumbnailRenderer"] as? [String: Any],
               let thumbs = (cropped["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
               let last = thumbs.last,
               let urlStr = last["url"] as? String {
                artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
            }
        }
        
        // 3. Fallback: Microformat
        if let microformat = json["microformat"] as? [String: Any],
           let dataRenderer = microformat["microformatDataRenderer"] as? [String: Any] {
            if title == "Album", let mTitle = dataRenderer["title"] as? String {
                title = mTitle
            }
            if artworkURL == nil,
               let thumb = dataRenderer["thumbnail"] as? [String: Any],
               let thumbs = thumb["thumbnails"] as? [[String: Any]],
               let last = thumbs.last,
               let urlStr = last["url"] as? String {
                artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
            }
        }
        
        // 4. Tracks list
        var sections: [[String: Any]] = []
        if let twoCol = (json["contents"] as? [String: Any])?["twoColumnBrowseResultsRenderer"] as? [String: Any],
           let sec = (twoCol["secondaryContents"] as? [String: Any])?["sectionListRenderer"] as? [String: Any],
           let contents = sec["contents"] as? [[String: Any]] {
            sections = contents
        } else if let singleCol = (json["contents"] as? [String: Any])?["singleColumnBrowseResultsRenderer"] as? [String: Any],
                  let tabs = singleCol["tabs"] as? [[String: Any]],
                  let firstTab = tabs.first,
                  let sec = (firstTab["tabRenderer"] as? [String: Any])?["content"] as? [String: Any],
                  let sectionList = sec["sectionListRenderer"] as? [String: Any],
                  let contents = sectionList["contents"] as? [[String: Any]] {
            sections = contents
        }
        
        var trackIdx = 1
        for s in sections {
            let shelf = s["musicShelfRenderer"] as? [String: Any] ?? s["musicPlaylistShelfRenderer"] as? [String: Any]
            guard let items = shelf?["contents"] as? [[String: Any]] else { continue }
            
            for item in items {
                guard let r = item["musicResponsiveListItemRenderer"] as? [String: Any] else { continue }
                var trackTitle = "Track"
                var trackArtist = artist
                var trackArtistId = artistId ?? "artist-\(artist)"
                var videoId = ""
                var duration: TimeInterval = 0
                var isExplicit = false
                
                // Badges
                if let badges = r["badges"] as? [[String: Any]] {
                    for b in badges {
                        if let badgeRenderer = b["musicInlineBadgeRenderer"] as? [String: Any],
                           let icon = badgeRenderer["icon"] as? [String: Any],
                           let iconType = icon["iconType"] as? String,
                           iconType.contains("EXPLICIT") {
                            isExplicit = true
                        }
                    }
                }
                
                // Title from flexColumns[0]
                if let flexCols = r["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
                    let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                    let runs = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                    if let first = runs.first {
                        trackTitle = first["text"] as? String ?? trackTitle
                    }
                    
                    // Col 1: Artist (if different from album artist)
                    if flexCols.count > 1 {
                        let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                        let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                        for run1 in runs1 {
                            let text = run1["text"] as? String ?? ""
                            let nav = run1["navigationEndpoint"] as? [String: Any]
                            let browse = nav?["browseEndpoint"] as? [String: Any]
                            if let bId = browse?["browseId"] as? String, bId.hasPrefix("UC") {
                                trackArtist = text
                                trackArtistId = bId
                            }
                        }
                    }
                }
                
                // Duration from fixedColumns[0]
                if let fixedCols = r["fixedColumns"] as? [[String: Any]], !fixedCols.isEmpty {
                    let fix0 = fixedCols[0]["musicResponsiveListItemFixedColumnRenderer"] as? [String: Any]
                    let runs = (fix0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                    if let first = runs.first, let durStr = first["text"] as? String {
                        duration = parseDuration(durStr)
                    }
                }
                
                // VideoId from overlay
                if let overlay = r["overlay"] as? [String: Any],
                   let thumbOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
                   let content = thumbOverlay["content"] as? [String: Any],
                   let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
                   let playNav = playBtn["playNavigationEndpoint"] as? [String: Any],
                   let watch = playNav["watchEndpoint"] as? [String: Any] {
                    videoId = watch["videoId"] as? String ?? ""
                }
                
                if !videoId.isEmpty {
                    songs.append(Song(
                        id: videoId,
                        title: trackTitle,
                        artistId: trackArtistId,
                        artistName: trackArtist,
                        albumId: id,
                        albumTitle: title,
                        artworkURL: artworkURL,
                        duration: duration,
                        trackNumber: trackIdx,
                        isExplicit: isExplicit
                    ))
                    trackIdx += 1
                }
            }
        }
        
        return Album(
            id: id,
            title: title,
            artist: artist,
            artistId: artistId,
            artworkURL: artworkURL,
            songs: songs,
            releaseDate: releaseDate,
            year: year,
            albumType: albumType,
            trackCount: songs.count,
            descriptionText: descriptionText
        )
    }
    
    // MARK: - Parsing Artist Browse Response
    private func parseArtistBrowse(id: String, json: [String: Any]) -> Artist {
        var name = "Artist"
        var artworkURL: URL?
        var heroImageURL: URL?
        var bio: String?
        var subscribers: String?
        var topSongs: [Song] = []
        var albums: [Album] = []
        var singles: [Album] = []
        var latestRelease: Album?
        var relatedArtists: [Artist] = []
        
        // 1. Header (musicImmersiveHeaderRenderer / musicVisualHeaderRenderer)
        let header = json["header"] as? [String: Any]
        let visualHeader = header?["musicImmersiveHeaderRenderer"] as? [String: Any] ?? header?["musicVisualHeaderRenderer"] as? [String: Any]
        if let vh = visualHeader {
            if let titleRuns = (vh["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                name = first["text"] as? String ?? name
            }
            if let descRuns = (vh["description"] as? [String: Any])?["runs"] as? [[String: Any]], let first = descRuns.first {
                bio = first["text"] as? String
            }
            if let subRuns = (vh["subscriptionButton"] as? [String: Any])?["subscribeButtonRenderer"] as? [String: Any],
               let subCount = (subRuns["subscriberCountText"] as? [String: Any])?["runs"] as? [[String: Any]], let first = subCount.first {
                subscribers = first["text"] as? String
            }
            
            if let thumb = vh["thumbnail"] as? [String: Any] {
                let thumbsDict = (thumb["musicThumbnailRenderer"] as? [String: Any])?["thumbnail"] as? [String: Any] ?? thumb
                if let thumbsList = thumbsDict["thumbnails"] as? [[String: Any]], !thumbsList.isEmpty {
                    if let last = thumbsList.last, let urlStr = last["url"] as? String {
                        heroImageURL = URL(string: urlStr)
                        artworkURL = ImageHelper.highResArtworkURL(from: heroImageURL)
                    }
                }
            }
        }
        
        // 2. Sections
        guard let singleCol = (json["contents"] as? [String: Any])?["singleColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = singleCol["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabContent = (firstTab["tabRenderer"] as? [String: Any])?["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sections = sectionList["contents"] as? [[String: Any]] else {
            return Artist(id: id, name: name, artworkURL: artworkURL, heroImageURL: heroImageURL)
        }
        
        for s in sections {
            let shelf = s["musicShelfRenderer"] as? [String: Any] ?? s["musicCarouselShelfRenderer"] as? [String: Any]
            guard let shelf = shelf, let items = shelf["contents"] as? [[String: Any]] else { continue }
            
            let titleText = extractShelfTitle(from: shelf).lowercased()
            
            // Top Songs
            if titleText.contains("top song") || (titleText.contains("song") && topSongs.isEmpty) {
                for item in items {
                    if let r = item["musicResponsiveListItemRenderer"] as? [String: Any] {
                        var trackTitle = "Track"
                        var videoId = ""
                        var thumbURL: URL?
                        var duration: TimeInterval = 0
                        var isExplicit = false
                        var albumName: String?
                        
                        if let badges = r["badges"] as? [[String: Any]] {
                            for b in badges {
                                if let badgeRenderer = b["musicInlineBadgeRenderer"] as? [String: Any],
                                   let icon = badgeRenderer["icon"] as? [String: Any],
                                   let iconType = icon["iconType"] as? String,
                                   iconType.contains("EXPLICIT") {
                                    isExplicit = true
                                }
                            }
                        }
                        
                        if let flexCols = r["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
                            let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                            let runs = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                            if let first = runs.first {
                                trackTitle = first["text"] as? String ?? trackTitle
                            }
                            if flexCols.count > 1 {
                                let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                                let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                                for r1 in runs1 {
                                    let t = r1["text"] as? String ?? ""
                                    if t.contains(":") {
                                        duration = parseDuration(t)
                                    } else if !t.isEmpty && t != "•" && t != name {
                                        albumName = t
                                    }
                                }
                            }
                        }
                        
                        if let fixedCols = r["fixedColumns"] as? [[String: Any]], !fixedCols.isEmpty {
                            let fix0 = fixedCols[0]["musicResponsiveListItemFixedColumnRenderer"] as? [String: Any]
                            let runs = (fix0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                            if let first = runs.first, let durStr = first["text"] as? String {
                                duration = parseDuration(durStr)
                            }
                        }
                        
                        if let overlay = r["overlay"] as? [String: Any],
                           let thumbOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
                           let content = thumbOverlay["content"] as? [String: Any],
                           let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
                           let playNav = playBtn["playNavigationEndpoint"] as? [String: Any],
                           let watch = playNav["watchEndpoint"] as? [String: Any] {
                            videoId = watch["videoId"] as? String ?? ""
                        }
                        
                        if let thumbRenderer = r["thumbnail"] as? [String: Any],
                           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
                           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
                           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
                           let last = thumbs.last,
                           let urlStr = last["url"] as? String {
                            thumbURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr), videoId: videoId)
                        }
                        
                        if !videoId.isEmpty {
                            topSongs.append(Song(
                                id: videoId,
                                title: trackTitle,
                                artistId: id,
                                artistName: name,
                                albumTitle: albumName,
                                artworkURL: thumbURL ?? artworkURL,
                                duration: duration,
                                isExplicit: isExplicit
                            ))
                        }
                    }
                }
            }
            
            // Albums
            else if titleText == "albums" || (titleText.contains("album") && !titleText.contains("single")) {
                for item in items {
                    if let twoRow = item["musicTwoRowItemRenderer"] as? [String: Any] {
                        var albumTitle = "Album"
                        var albumId = ""
                        var albumArtwork: URL?
                        var year: String?
                        
                        let nav = twoRow["navigationEndpoint"] as? [String: Any]
                        if let browse = nav?["browseEndpoint"] as? [String: Any],
                           let bId = browse["browseId"] as? String {
                            albumId = bId
                        }
                        
                        if let titleRuns = (twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                            albumTitle = first["text"] as? String ?? albumTitle
                            if albumId.isEmpty,
                               let nav = first["navigationEndpoint"] as? [String: Any],
                               let browse = nav["browseEndpoint"] as? [String: Any],
                               let bId = browse["browseId"] as? String {
                                albumId = bId
                            }
                        }
                        
                        if let subRuns = (twoRow["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                            for r in subRuns {
                                let t = r["text"] as? String ?? ""
                                if t.count == 4 && Int(t) != nil {
                                    year = t
                                }
                            }
                        }
                        
                        if let thumbRenderer = twoRow["thumbnailRenderer"] as? [String: Any],
                           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
                           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
                           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
                           let last = thumbs.last,
                           let urlStr = last["url"] as? String {
                            albumArtwork = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
                        }
                        
                        if !albumId.isEmpty {
                            albums.append(Album(
                                id: albumId,
                                title: albumTitle,
                                artist: name,
                                artistId: id,
                                artworkURL: albumArtwork,
                                year: year,
                                albumType: "Album"
                            ))
                        }
                    }
                }
            }
            
            // Singles & EPs
            else if titleText.contains("single") || titleText.contains("ep") {
                for item in items {
                    if let twoRow = item["musicTwoRowItemRenderer"] as? [String: Any] {
                        var singleTitle = "Single"
                        var singleId = ""
                        var singleArtwork: URL?
                        var year: String?
                        
                        let nav = twoRow["navigationEndpoint"] as? [String: Any]
                        if let browse = nav?["browseEndpoint"] as? [String: Any],
                           let bId = browse["browseId"] as? String {
                            singleId = bId
                        }
                        
                        if let titleRuns = (twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                            singleTitle = first["text"] as? String ?? singleTitle
                            if singleId.isEmpty,
                               let nav = first["navigationEndpoint"] as? [String: Any],
                               let browse = nav["browseEndpoint"] as? [String: Any],
                               let bId = browse["browseId"] as? String {
                                singleId = bId
                            }
                        }
                        
                        if let subRuns = (twoRow["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                            for r in subRuns {
                                let t = r["text"] as? String ?? ""
                                if t.count == 4 && Int(t) != nil {
                                    year = t
                                }
                            }
                        }
                        
                        if let thumbRenderer = twoRow["thumbnailRenderer"] as? [String: Any],
                           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
                           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
                           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
                           let last = thumbs.last,
                           let urlStr = last["url"] as? String {
                            singleArtwork = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
                        }
                        
                        if !singleId.isEmpty {
                            singles.append(Album(
                                id: singleId,
                                title: singleTitle,
                                artist: name,
                                artistId: id,
                                artworkURL: singleArtwork,
                                year: year,
                                albumType: "Single"
                            ))
                        }
                    }
                }
            }
            
            // Fans might also like / Similar Artists
            else if titleText.contains("fan") || titleText.contains("like") || titleText.contains("similar") || titleText.contains("featured on") {
                for item in items {
                    if let twoRow = item["musicTwoRowItemRenderer"] as? [String: Any] {
                        var relName = "Artist"
                        var relId = ""
                        var relArtwork: URL?
                        var relSub: String?
                        
                        let nav = twoRow["navigationEndpoint"] as? [String: Any]
                        if let browse = nav?["browseEndpoint"] as? [String: Any],
                           let bId = browse["browseId"] as? String, bId.hasPrefix("UC") {
                            relId = bId
                        }
                        
                        if let titleRuns = (twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                            relName = first["text"] as? String ?? relName
                            if relId.isEmpty,
                               let nav = first["navigationEndpoint"] as? [String: Any],
                               let browse = nav["browseEndpoint"] as? [String: Any],
                               let bId = browse["browseId"] as? String {
                                relId = bId
                            }
                        }
                        
                        if let subRuns = (twoRow["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                            relSub = subRuns.compactMap { $0["text"] as? String }.joined()
                        }
                        
                        if let thumbRenderer = twoRow["thumbnailRenderer"] as? [String: Any],
                           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
                           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
                           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
                           let last = thumbs.last,
                           let urlStr = last["url"] as? String {
                            relArtwork = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
                        }
                        
                        if !relId.isEmpty {
                            relatedArtists.append(Artist(
                                id: relId,
                                name: relName,
                                artworkURL: relArtwork,
                                subscribers: relSub
                            ))
                        }
                    }
                }
            }
        }
        
        // Latest Release assignment (from singles or albums)
        latestRelease = singles.first ?? albums.first
        
        return Artist(
            id: id,
            name: name,
            artworkURL: artworkURL,
            heroImageURL: heroImageURL,
            bio: bio,
            subscribers: subscribers,
            topSongs: topSongs,
            albums: albums,
            singles: singles,
            latestRelease: latestRelease,
            relatedArtists: relatedArtists
        )
    }
    
    // MARK: - Parsing Playlist Browse
    private func parsePlaylistBrowse(id: String, json: [String: Any]) -> Playlist {
        var title = "Playlist"
        var author: String?
        var descriptionText: String?
        var artworkURL: URL?
        var songs: [Song] = []
        
        let header = json["header"] as? [String: Any]
        if let detailHeader = header?["musicDetailHeaderRenderer"] as? [String: Any] {
            if let titleRuns = (detailHeader["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                title = first["text"] as? String ?? title
            }
            if let subRuns = (detailHeader["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]], let first = subRuns.first {
                author = first["text"] as? String
            }
            if let descRuns = (detailHeader["description"] as? [String: Any])?["runs"] as? [[String: Any]], let first = descRuns.first {
                descriptionText = first["text"] as? String
            }
            if let thumbRenderer = detailHeader["thumbnail"] as? [String: Any],
               let cropped = thumbRenderer["croppedSquareThumbnailRenderer"] as? [String: Any],
               let thumbs = (cropped["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
               let last = thumbs.last,
               let urlStr = last["url"] as? String {
                artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr))
            }
        }
        
        // Tracks
        if let twoCol = (json["contents"] as? [String: Any])?["twoColumnBrowseResultsRenderer"] as? [String: Any],
           let sec = (twoCol["secondaryContents"] as? [String: Any])?["sectionListRenderer"] as? [String: Any],
           let contents = sec["contents"] as? [[String: Any]] {
            for s in contents {
                let shelf = s["musicPlaylistShelfRenderer"] as? [String: Any] ?? s["musicShelfRenderer"] as? [String: Any]
                guard let items = shelf?["contents"] as? [[String: Any]] else { continue }
                for item in items {
                    guard let r = item["musicResponsiveListItemRenderer"] as? [String: Any] else { continue }
                    var trackTitle = "Track"
                    var trackArtist = "Artist"
                    var trackArtistId = "artist-yt"
                    var videoId = ""
                    var duration: TimeInterval = 0
                    
                    if let flexCols = r["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
                        let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                        let runs = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                        if let first = runs.first {
                            trackTitle = first["text"] as? String ?? trackTitle
                        }
                        if flexCols.count > 1 {
                            let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                            let runs1 = (col1?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                            if let first = runs1.first {
                                trackArtist = first["text"] as? String ?? trackArtist
                                let nav = first["navigationEndpoint"] as? [String: Any]
                                let browse = nav?["browseEndpoint"] as? [String: Any]
                                trackArtistId = browse?["browseId"] as? String ?? "artist-\(trackArtist)"
                            }
                        }
                    }
                    
                    if let overlay = r["overlay"] as? [String: Any],
                       let thumbOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
                       let content = thumbOverlay["content"] as? [String: Any],
                       let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
                       let playNav = playBtn["playNavigationEndpoint"] as? [String: Any],
                       let watch = playNav["watchEndpoint"] as? [String: Any] {
                        videoId = watch["videoId"] as? String ?? ""
                    }
                    
                    if !videoId.isEmpty {
                        songs.append(Song(
                            id: videoId,
                            title: trackTitle,
                            artistId: trackArtistId,
                            artistName: trackArtist,
                            artworkURL: artworkURL,
                            duration: duration
                        ))
                    }
                }
            }
        }
        
        return Playlist(
            id: id,
            title: title,
            author: author,
            descriptionText: descriptionText,
            artworkURL: artworkURL,
            songs: songs,
            isUserCreated: false,
            trackCount: songs.count
        )
    }
    
    // MARK: - Helper to Extract Shelf Title
    private func extractShelfTitle(from shelf: [String: Any]) -> String {
        if let titleObj = shelf["title"] as? [String: Any],
           let runs = titleObj["runs"] as? [[String: Any]],
           let first = runs.first,
           let text = first["text"] as? String {
            return text
        }
        if let header = shelf["header"] as? [String: Any],
           let basic = header["musicCarouselShelfBasicHeaderRenderer"] as? [String: Any],
           let titleObj = basic["title"] as? [String: Any],
           let runs = titleObj["runs"] as? [[String: Any]],
           let first = runs.first,
           let text = first["text"] as? String {
            return text
        }
        return ""
    }
    
    private func parseDuration(_ string: String) -> TimeInterval {
        let parts = string.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return 0
    }
}
