import Foundation

// MARK: - LyricsCache
actor LyricsCache {
    private var storage: [String: [LyricsService.LyricLine]] = [:]
    
    func get(_ key: String) -> [LyricsService.LyricLine]? {
        storage[key]
    }
    
    func set(_ key: String, lines: [LyricsService.LyricLine]) {
        storage[key] = lines
    }
}

// MARK: - LyricsService
/// High-speed lyrics service querying lrclib.net with intelligent title cleaning,
/// fuzzy search fallbacks, and persistent in-memory caching for 0ms instant display.
public final class LyricsService: @unchecked Sendable {
    public static let shared = LyricsService()
    
    private let client: HTTPClient
    private let cache = LyricsCache()
    
    public init(client: HTTPClient = .shared) {
        self.client = client
    }
    
    public struct LyricLine: Identifiable, Sendable {
        public let id = UUID()
        public let time: TimeInterval
        public let text: String
        
        public init(time: TimeInterval, text: String) {
            self.time = time
            self.text = text
        }
    }
    
    // MARK: - Preload Lyrics
    public func preloadLyrics(song: Song) async {
        _ = await fetchLyrics(trackName: song.title, artistName: song.artistName, duration: Int(song.duration), videoId: song.id)
    }
    
    // MARK: - Fetch Synchronized Lyrics
    public func fetchLyrics(trackName: String, artistName: String, duration: Int? = nil, videoId: String? = nil) async -> [LyricLine] {
        let cacheKey = videoId ?? "\(trackName.lowercased())_\(artistName.lowercased())"
        
        if let cached = await cache.get(cacheKey), !cached.isEmpty {
            return cached
        }
        
        let cleanedTrack = cleanTrackTitle(trackName)
        let cleanedArtist = cleanArtistName(artistName)
        
        // 1. Try Direct Exact Match
        if let directURL = Endpoints.lyrics(trackName: cleanedTrack, artistName: cleanedArtist, duration: duration) {
            if let lines = await fetchFromURL(directURL), !lines.isEmpty {
                await cache.set(cacheKey, lines: lines)
                return lines
            }
        }
        
        // 2. Fallback to lrclib.net Search Query
        let query = "\(cleanedTrack) \(cleanedArtist)"
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let searchURL = URL(string: "https://lrclib.net/api/search?q=\(encodedQuery)") {
            if let lines = await fetchFromSearchURL(searchURL), !lines.isEmpty {
                await cache.set(cacheKey, lines: lines)
                return lines
            }
        }
        
        return []
    }
    
    private func fetchFromURL(_ url: URL) async -> [LyricLine]? {
        do {
            let data = try await client.get(url: url, headers: ["User-Agent": "Demus/2.0.22"])
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                    return parseLRC(synced)
                } else if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
                    return parsePlain(plain)
                }
            }
        } catch {}
        return nil
    }
    
    private func fetchFromSearchURL(_ url: URL) async -> [LyricLine]? {
        do {
            let data = try await client.get(url: url, headers: ["User-Agent": "Demus/2.0.22"])
            if let items = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                // Find first item with synced lyrics or plain lyrics
                for item in items {
                    if let synced = item["syncedLyrics"] as? String, !synced.isEmpty {
                        return parseLRC(synced)
                    }
                }
                for item in items {
                    if let plain = item["plainLyrics"] as? String, !plain.isEmpty {
                        return parsePlain(plain)
                    }
                }
            }
        } catch {}
        return nil
    }
    
    // MARK: - Cleaning YouTube Title Noise
    private func cleanTrackTitle(_ raw: String) -> String {
        var title = raw
        
        // Remove text in parentheses / brackets like (Official Video), [Lyrics], (feat. ...), [4K]
        let patterns = [
            "\\s*\\([oO]fficial\\s*(music\\s*)?video\\)",
            "\\s*\\[[oO]fficial\\s*(music\\s*)?video\\]",
            "\\s*\\([oO]fficial\\s*audio\\)",
            "\\s*\\[[oO]fficial\\s*audio\\]",
            "\\s*\\([lL]yrics?\\)",
            "\\s*\\[[lL]yrics?\\]",
            "\\s*\\([vV]isualizer\\)",
            "\\s*\\[[vV]isualizer\\]",
            "\\s*\\(feat\\..*?\\)",
            "\\s*\\[feat\\..*?\\]",
            "\\s*\\(ft\\..*?\\)",
            "\\s*\\[ft\\..*?\\]",
            "\\s*feat\\..*",
            "\\s*ft\\..*",
            "\\s*\\[[0-9]+[pPkK]\\]",
            "\\s*\\([hH][dD]\\)",
            "\\s*\\[[hH][dD]\\]"
        ]
        
        for pat in patterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                let range = NSRange(title.startIndex..<title.endIndex, in: title)
                title = regex.stringByReplacingMatches(in: title, options: [], range: range, withTemplate: "")
            }
        }
        
        // If title contains " - ", usually "Artist - Song Title", take the song part
        if title.contains(" - ") {
            let parts = title.components(separatedBy: " - ")
            if parts.count >= 2 {
                title = parts[1]
            }
        }
        
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func cleanArtistName(_ raw: String) -> String {
        var artist = raw
        if artist.contains(" - Topic") {
            artist = artist.replacingOccurrences(of: " - Topic", with: "")
        }
        if artist.contains("VEVO") {
            artist = artist.replacingOccurrences(of: "VEVO", with: "")
        }
        return artist.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Parse LRC Format [mm:ss.xx]
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let lines = lrc.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("[") else { continue }
            
            if let closeBracket = trimmed.firstIndex(of: "]") {
                let timeString = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
                let text = String(trimmed[trimmed.index(after: closeBracket)...]).trimmingCharacters(in: .whitespaces)
                
                let timeParts = timeString.components(separatedBy: ":")
                if timeParts.count == 2,
                   let mins = Double(timeParts[0]),
                   let secs = Double(timeParts[1]) {
                    let totalSeconds = mins * 60 + secs
                    if !text.isEmpty {
                        result.append(LyricLine(time: totalSeconds, text: text))
                    }
                }
            }
        }
        return result
    }
    
    private func parsePlain(_ plain: String) -> [LyricLine] {
        let lines = plain.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.enumerated().map { index, text in
            LyricLine(time: Double(index * 4), text: text)
        }
    }
}
