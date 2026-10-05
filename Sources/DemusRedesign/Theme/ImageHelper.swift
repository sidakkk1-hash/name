import Foundation

// MARK: - ImageHelper
/// Transforms low-resolution YouTube Music thumbnails into crystal clear HD/4K artwork.
public enum ImageHelper {
    public static func highResArtworkURL(from url: URL?, videoId: String? = nil) -> URL? {
        guard let url = url else {
            if let vid = videoId, !vid.isEmpty {
                return URL(string: "https://i.ytimg.com/vi/\(vid)/maxresdefault.jpg")
            }
            return nil
        }
        
        var urlString = url.absoluteString
        
        // 1. Upgrade googleusercontent / ytm sizing tokens (=w120-h120 -> =w1200-h1200)
        if urlString.contains("=w") || urlString.contains("-w") {
            if let regex = try? NSRegularExpression(pattern: "[=-]w\\d+-[a-zA-Z0-9_-]+", options: []) {
                let range = NSRange(urlString.startIndex..<urlString.endIndex, in: urlString)
                urlString = regex.stringByReplacingMatches(in: urlString, options: [], range: range, withTemplate: "=w1200-h1200-l90-rj")
            }
        }
        
        // 2. Upgrade /s120/ or /s60/ to /s1200/
        if let regex2 = try? NSRegularExpression(pattern: "/s\\d+/", options: []) {
            let range = NSRange(urlString.startIndex..<urlString.endIndex, in: urlString)
            urlString = regex2.stringByReplacingMatches(in: urlString, options: [], range: range, withTemplate: "/s1200/")
        }
        
        // 3. Upgrade standard YouTube low-res thumbnails to maxresdefault or hqdefault
        if urlString.contains("default.jpg") && !urlString.contains("maxresdefault.jpg") {
            if let vid = videoId, !vid.isEmpty {
                return URL(string: "https://i.ytimg.com/vi/\(vid)/maxresdefault.jpg")
            }
            urlString = urlString.replacingOccurrences(of: "default.jpg", with: "maxresdefault.jpg")
        }
        
        return URL(string: urlString) ?? url
    }
}
