import Foundation

// MARK: - ImageHelper
/// High-speed artwork sizing utility that delivers optimal Retina quality at minimum payload size.
public enum ImageHelper {
    public enum ImageResolution {
        case thumbnail  // Lists, mini player, queue (w300)
        case card       // Explore cards, albums, artists (w450)
        case full       // Now playing full screen artwork (w600)
        
        var dimension: Int {
            switch self {
            case .thumbnail: return 300
            case .card: return 450
            case .full: return 600
            }
        }
    }
    
    public static func highResArtworkURL(from url: URL?, videoId: String? = nil, resolution: ImageResolution = .full) -> URL? {
        guard let url = url else {
            if let vid = videoId, !vid.isEmpty {
                return URL(string: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg")
            }
            return nil
        }
        
        var urlString = url.absoluteString
        let size = resolution.dimension
        let token = "=w\(size)-h\(size)-l90-rj"
        
        // 1. Upgrade googleusercontent / ytm sizing tokens
        if urlString.contains("=w") || urlString.contains("-w") {
            if let regex = try? NSRegularExpression(pattern: "[=-]w\\d+-[a-zA-Z0-9_-]+", options: []) {
                let range = NSRange(urlString.startIndex..<urlString.endIndex, in: urlString)
                urlString = regex.stringByReplacingMatches(in: urlString, options: [], range: range, withTemplate: token)
            }
        }
        
        // 2. Upgrade /s120/ or /s60/ to /s(size)/
        if let regex2 = try? NSRegularExpression(pattern: "/s\\d+/", options: []) {
            let range = NSRange(urlString.startIndex..<urlString.endIndex, in: urlString)
            urlString = regex2.stringByReplacingMatches(in: urlString, options: [], range: range, withTemplate: "/s\(size)/")
        }
        
        // 3. Normalize ytimg default thumbs: use hqdefault.jpg for guaranteed instant 100% availability
        if urlString.contains("default.jpg") {
            if let vid = videoId, !vid.isEmpty {
                return URL(string: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg")
            }
            urlString = urlString.replacingOccurrences(of: "maxresdefault.jpg", with: "hqdefault.jpg")
            urlString = urlString.replacingOccurrences(of: "default.jpg", with: "hqdefault.jpg")
        }
        
        return URL(string: urlString) ?? url
    }
}
