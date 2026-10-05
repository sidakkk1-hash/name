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
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "browseId": id
        ]
        
        do {
            let json = try await client.postJSON(urlString: Endpoints.browse, body: body)
            return parseAlbumBrowse(id: id, json: json)
        } catch {
            return nil
        }
    }
    
    // MARK: - Fetch Real Artist Profile & Discography
    public func fetchArtist(id: String) async -> Artist? {
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "browseId": id
        ]
        
        do {
            let json = try await client.postJSON(urlString: Endpoints.browse, body: body)
            return parseArtistBrowse(id: id, json: json)
        } catch {
            return nil
        }
    }
    
    // MARK: - Parsing Album Browse Response
    private func parseAlbumBrowse(id: String, json: [String: Any]) -> Album {
        var title = "Album"
        var artist = "Artist"
        var artworkURL: URL?
        var releaseDate: String?
        var songs: [Song] = []
        
        // Header - support musicDetailHeaderRenderer, musicResponsiveHeaderRenderer, and microformat
        let header = json["header"] as? [String: Any]
        if let detailHeader = header?["musicDetailHeaderRenderer"] as? [String: Any] {
            if let titleRuns = (detailHeader["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                title = first["text"] as? String ?? title
            }
            if let subtitleRuns = (detailHeader["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                if !subtitleRuns.isEmpty {
                    artist = subtitleRuns[0]["text"] as? String ?? artist
                }
                if subtitleRuns.count >= 3 {
                    releaseDate = subtitleRuns[2]["text"] as? String
                }
            }
            if let thumbRenderer = detailHeader["thumbnail"] as? [String: Any],
               let cropped = thumbRenderer["croppedSquareThumbnailRenderer"] as? [String: Any],
               let thumbs = (cropped["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
               let last = thumbs.last,
               let urlStr = last["url"] as? String {
                artworkURL = URL(string: urlStr)
            }
        }
        
        // Also check twoColumn tabs header for musicResponsiveHeaderRenderer
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
            if let strapline = (responsiveHeader["straplineTextOne"] as? [String: Any])?["runs"] as? [[String: Any]], let first = strapline.first {
                artist = first["text"] as? String ?? artist
            }
            if let subtitleRuns = (responsiveHeader["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                let texts = subtitleRuns.compactMap { $0["text"] as? String }
                if let lastText = texts.last, !lastText.trimmingCharacters(in: .whitespaces).isEmpty {
                    releaseDate = lastText
                }
            }
            if let thumbRenderer = responsiveHeader["thumbnail"] as? [String: Any],
               let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
               let thumbnail = musicThumb["thumbnail"] as? [String: Any],
               let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
               let last = thumbs.last,
               let urlStr = last["url"] as? String {
                artworkURL = URL(string: urlStr)
            }
        }
        
        // Microformat Fallback
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
                artworkURL = URL(string: urlStr)
            }
        }
        
        // Tracks list
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
        
        for s in sections {
            let shelf = s["musicShelfRenderer"] as? [String: Any] ?? s["musicPlaylistShelfRenderer"] as? [String: Any]
            guard let items = shelf?["contents"] as? [[String: Any]] else { continue }
            
            for item in items {
                guard let r = item["musicResponsiveListItemRenderer"] as? [String: Any] else { continue }
                var trackTitle = "Track"
                var videoId = ""
                
                if let flexCols = r["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
                    let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                    let runs = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                    if let first = runs.first {
                        trackTitle = first["text"] as? String ?? trackTitle
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
                        artistName: artist,
                        albumTitle: title,
                        artworkURL: artworkURL
                    ))
                }
            }
        }
        
        return Album(id: id, title: title, artist: artist, artworkURL: artworkURL, songs: songs, releaseDate: releaseDate)
    }
    
    // MARK: - Parsing Artist Browse Response
    private func parseArtistBrowse(id: String, json: [String: Any]) -> Artist {
        var name = "Artist"
        var artworkURL: URL?
        var topSongs: [Song] = []
        var albums: [Album] = []
        
        // Header
        let header = json["header"] as? [String: Any]
        let visualHeader = header?["musicImmersiveHeaderRenderer"] as? [String: Any] ?? header?["musicVisualHeaderRenderer"] as? [String: Any]
        if let vh = visualHeader {
            if let titleRuns = (vh["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                name = first["text"] as? String ?? name
            }
            if let thumb = vh["thumbnail"] as? [String: Any],
               let thumbs = (thumb["musicThumbnailRenderer"] as? [String: Any])?["thumbnail"] as? [String: Any] ?? thumb["thumbnail"] as? [String: Any],
               let list = (thumbs as? [String: Any])?["thumbnails"] as? [[String: Any]],
               let last = list.last,
               let urlStr = last["url"] as? String {
                artworkURL = URL(string: urlStr)
            }
        }
        
        // Sections
        guard let singleCol = (json["contents"] as? [String: Any])?["singleColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = singleCol["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabContent = (firstTab["tabRenderer"] as? [String: Any])?["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sections = sectionList["contents"] as? [[String: Any]] else {
            return Artist(id: id, name: name, artworkURL: artworkURL)
        }
        
        for s in sections {
            let shelf = s["musicShelfRenderer"] as? [String: Any] ?? s["musicCarouselShelfRenderer"] as? [String: Any]
            guard let shelf = shelf, let items = shelf["contents"] as? [[String: Any]] else { continue }
            
            let headerTitle = (shelf["title"] as? [String: Any])?["runs"] as? [[String: Any]] ??
                ((shelf["header"] as? [String: Any])?["musicCarouselShelfBasicHeaderRenderer"] as? [String: Any])?["title"] as? [String: Any]? ?? [:]
            let sectionName = (headerTitle as? [String: Any])?["runs"] as? [[String: Any]]
            let titleText = sectionName?.first?["text"] as? String ?? ""
            
            // Top Songs
            if titleText.lowercased().contains("song") || topSongs.isEmpty {
                for item in items {
                    if let r = item["musicResponsiveListItemRenderer"] as? [String: Any] {
                        var trackTitle = "Track"
                        var videoId = ""
                        var thumbURL: URL?
                        
                        if let flexCols = r["flexColumns"] as? [[String: Any]], !flexCols.isEmpty {
                            let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                            let runs = (col0?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                            if let first = runs.first {
                                trackTitle = first["text"] as? String ?? trackTitle
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
                            thumbURL = URL(string: urlStr)
                        }
                        
                        if !videoId.isEmpty {
                            topSongs.append(Song(
                                id: videoId,
                                title: trackTitle,
                                artistName: name,
                                artworkURL: thumbURL ?? artworkURL
                            ))
                        }
                    }
                }
            }
            
            // Albums & Singles
            if titleText.lowercased().contains("album") || titleText.lowercased().contains("release") {
                for item in items {
                    if let twoRow = item["musicTwoRowItemRenderer"] as? [String: Any] {
                        var albumTitle = "Album"
                        var albumId = UUID().uuidString
                        var albumArtwork: URL?
                        
                        if let titleRuns = (twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]], let first = titleRuns.first {
                            albumTitle = first["text"] as? String ?? albumTitle
                            if let nav = first["navigationEndpoint"] as? [String: Any],
                               let browse = nav["browseEndpoint"] as? [String: Any],
                               let bId = browse["browseId"] as? String {
                                albumId = bId
                            }
                        }
                        
                        if let thumbRenderer = twoRow["thumbnailRenderer"] as? [String: Any],
                           let musicThumb = thumbRenderer["musicThumbnailRenderer"] as? [String: Any],
                           let thumbnail = musicThumb["thumbnail"] as? [String: Any],
                           let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
                           let last = thumbs.last,
                           let urlStr = last["url"] as? String {
                            albumArtwork = URL(string: urlStr)
                        }
                        
                        albums.append(Album(id: albumId, title: albumTitle, artist: name, artworkURL: albumArtwork))
                    }
                }
            }
        }
        
        return Artist(id: id, name: name, artworkURL: artworkURL, topSongs: topSongs, albums: albums)
    }
}
