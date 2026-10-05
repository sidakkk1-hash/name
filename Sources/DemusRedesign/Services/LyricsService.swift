import Foundation

// MARK: - LyricsService
/// Real lyrics service querying lrclib.net (the exact provider used in Demus).
public final class LyricsService: @unchecked Sendable {
    public static let shared = LyricsService()
    
    private let client: HTTPClient
    
    public init(client: HTTPClient = .shared) {
        self.client = client
    }
    
    public struct LyricLine: Identifiable, Sendable {
        public let id = UUID()
        public let time: TimeInterval
        public let text: String
    }
    
    // MARK: - Fetch Synchronized Lyrics
    public func fetchLyrics(trackName: String, artistName: String, duration: Int? = nil) async -> [LyricLine] {
        guard let url = Endpoints.lyrics(trackName: trackName, artistName: artistName, duration: duration) else {
            return []
        }
        
        do {
            let data = try await client.get(url: url, headers: ["User-Agent": "Demus/2.0.22"])
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let synced = json["syncedLyrics"] as? String {
                return parseLRC(synced)
            } else if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let plain = json["plainLyrics"] as? String {
                // If only plain text lyrics available, space them out
                let lines = plain.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                return lines.enumerated().map { index, text in
                    LyricLine(time: Double(index * 4), text: text)
                }
            }
        } catch {
            // Fallback empty
        }
        return []
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
}
