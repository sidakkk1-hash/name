import Foundation

// MARK: - Innertube & Demus API Endpoints
public enum Endpoints {
    // YouTube Music Innertube API Base
    public static let ytmBase = "https://music.youtube.com/youtubei/v1"
    public static let ytBase = "https://www.youtube.com/youtubei/v1"
    
    // Core Endpoints
    public static let search = "\(ytmBase)/search?prettyPrint=false"
    public static let browse = "\(ytmBase)/browse?prettyPrint=false"
    public static let next = "\(ytmBase)/next?prettyPrint=false"
    public static let player = "\(ytBase)/player"
    public static let ytmPlayer = "\(ytmBase)/player"
    
    // Google Suggestions Autocomplete
    public static func searchSuggestions(for query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://clients1.google.com/complete/search?client=youtube&gs_ri=youtube&ds=yt&q=\(encoded)")
    }
    
    // LRCLIB Lyrics API (Used natively by Demus)
    public static func lyrics(trackName: String, artistName: String, duration: Int? = nil) -> URL? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]
        if let d = duration, d > 0 {
            items.append(URLQueryItem(name: "duration", value: String(d)))
        }
        components?.queryItems = items
        return components?.url
    }
    
    // iTunes Search API (Metadata & Preview Fallback)
    public static func iTunesSearch(query: String, limit: Int = 20) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=\(limit)")
    }
    
    // YouTube Music Filter Parameters
    public enum SearchFilter: String {
        case songs = "EgWKAQIIAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D"
        case videos = "EgWKAQIgAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D"
        case albums = "EgWKAQIYAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D"
        case artists = "EgWKAQIQAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D"
        case playlists = "EgWKAQIoAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D"
    }
}
