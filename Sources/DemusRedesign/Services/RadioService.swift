import Foundation

// MARK: - RadioService
/// Fetches algorithmic Up Next / Related songs using YouTube Music's Radio endpoint.
public final class RadioService: @unchecked Sendable {
    public static let shared = RadioService()
    
    private let client: HTTPClient
    
    public init(client: HTTPClient = .shared) {
        self.client = client
    }
    
    // MARK: - Fetch Up Next Radio Queue
    public func fetchUpNext(videoId: String) async -> [Song] {
        guard !videoId.isEmpty else { return [] }
        
        let body: [String: Any] = [
            "context": HTTPClient.makeYTMContext(),
            "videoId": videoId,
            "playlistId": "RDAMVM\(videoId)",
            "isAudioOnly": true
        ]
        
        do {
            let json = try await client.postJSON(urlString: Endpoints.next, body: body)
            return parseQueueItems(from: json, currentId: videoId)
        } catch {
            print("[RadioService] Error fetching radio queue:", error)
            return []
        }
    }
    
    // MARK: - Parse playlistPanelVideoRenderer
    private func parseQueueItems(from json: [String: Any], currentId: String) -> [Song] {
        guard let contents = json["contents"] as? [String: Any],
              let singleCol = contents["singleColumnMusicWatchNextResultsRenderer"] as? [String: Any],
              let tabbed = singleCol["tabbedRenderer"] as? [String: Any],
              let watchNext = tabbed["watchNextTabbedResultsRenderer"] as? [String: Any],
              let tabs = watchNext["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let content = tabRenderer["content"] as? [String: Any],
              let queueRenderer = content["musicQueueRenderer"] as? [String: Any],
              let playlistContent = queueRenderer["content"] as? [String: Any],
              let panelRenderer = playlistContent["playlistPanelRenderer"] as? [String: Any],
              let items = panelRenderer["contents"] as? [[String: Any]] else {
            return []
        }
        
        var songs: [Song] = []
        
        for item in items {
            guard let r = item["playlistPanelVideoRenderer"] as? [String: Any],
                  let vid = r["videoId"] as? String,
                  vid != currentId else { continue }
            
            var title = "Unknown Title"
            if let titleObj = r["title"] as? [String: Any],
               let runs = titleObj["runs"] as? [[String: Any]],
               let first = runs.first,
               let text = first["text"] as? String {
                title = text
            }
            
            var artist = "Unknown Artist"
            if let byline = r["longBylineText"] as? [String: Any],
               let runs = byline["runs"] as? [[String: Any]],
               let first = runs.first,
               let text = first["text"] as? String {
                artist = text
            }
            
            var duration: TimeInterval = 180
            if let lengthObj = r["lengthText"] as? [String: Any],
               let runs = lengthObj["runs"] as? [[String: Any]],
               let first = runs.first,
               let text = first["text"] as? String {
                let parts = text.split(separator: ":").compactMap { Double($0) }
                if parts.count == 2 {
                    duration = parts[0] * 60 + parts[1]
                } else if parts.count == 3 {
                    duration = parts[0] * 3600 + parts[1] * 60 + parts[2]
                }
            }
            
            var artworkURL: URL?
            if let thumbObj = r["thumbnail"] as? [String: Any],
               let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
               let last = thumbs.last,
               let urlStr = last["url"] as? String {
                artworkURL = ImageHelper.highResArtworkURL(from: URL(string: urlStr), videoId: vid)
            }
            
            let song = Song(
                id: vid,
                title: title,
                artistName: artist,
                artworkURL: artworkURL,
                duration: duration
            )
            songs.append(song)
        }
        
        return songs
    }
}
