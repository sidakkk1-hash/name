import Foundation

// MARK: - StreamResolutionError
public enum StreamResolutionError: LocalizedError, Sendable {
    case streamResolutionFailed
    case noAudioFormat
    case http403
    case httpStatus(Int)
    
    public var errorDescription: String? {
        switch self {
        case .streamResolutionFailed: return "Native failure: StreamResolutionFailed"
        case .noAudioFormat: return "Native failure: NoAudioFormat"
        case .http403: return "Native failure: HTTP403"
        case .httpStatus(let code): return "Native failure: HTTP\(code)"
        }
    }
}

// MARK: - StreamResolutionService
/// Resolves real playable audio streams for AVPlayer using YouTube Innertube player endpoint.
public final class StreamResolutionService: @unchecked Sendable {
    public static let shared = StreamResolutionService()
    
    private let client: HTTPClient
    
    public struct StreamDiagnosticInfo: Sendable {
        public let httpStatus: Int
        public let contentType: String
        public let acceptRanges: String
        public let contentRange: String
        public let contentLength: String
        public let mimeType: String
        public let codec: String
        public let bitrate: Int
        public let urlHost: String
    }
    
    public private(set) var latestDiagnostic: StreamDiagnosticInfo?
    
    public init(client: HTTPClient = .shared) {
        self.client = client
    }
    
    public struct ResolvedStream: Sendable {
        public let url: URL
        public let isHLS: Bool
        public let duration: TimeInterval
        public let bitrate: Int?
        public let mimeType: String?
        public let headers: [String: String]?
        
        public init(
            url: URL,
            isHLS: Bool,
            duration: TimeInterval,
            bitrate: Int? = nil,
            mimeType: String? = nil,
            headers: [String: String]? = nil
        ) {
            self.url = url
            self.isHLS = isHLS
            self.duration = duration
            self.bitrate = bitrate
            self.mimeType = mimeType
            self.headers = headers
        }
    }
    
    // MARK: - Resolve Playable Audio Stream for Song
    public func resolveStream(for song: Song) async throws -> ResolvedStream {
        // If song already has a direct streamURL, use it
        if let direct = song.streamURL {
            return ResolvedStream(
                url: direct,
                isHLS: direct.pathExtension == "m3u8",
                duration: song.duration,
                bitrate: nil,
                mimeType: "audio/mp4",
                headers: nil
            )
        }
        
        let videoId = song.id
        let iosUA = "com.google.ios.youtube/20.25.4 (iPhone17,1; U; CPU iOS 18_5 like Mac OS X)"
        let playerHeaders: [String: String] = [
            "User-Agent": iosUA,
            "X-YouTube-Client-Name": "5",
            "X-YouTube-Client-Version": "20.25.4"
        ]
        
        let body: [String: Any] = [
            "context": HTTPClient.makeIOSContext(),
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        
        let json: [String: Any]
        do {
            json = try await client.postJSON(urlString: Endpoints.player, body: body, headers: playerHeaders)
        } catch {
            print("[StreamResolutionService] Innertube player request failed for \(videoId): \(error)")
            throw StreamResolutionError.streamResolutionFailed
        }
        
        return try await parseAndVerifyStreamingData(json: json, videoId: videoId, songDuration: song.duration, iosUA: iosUA)
    }
    
    // MARK: - Parse and Verify Streaming Data with URLSession Range Preflight
    private func parseAndVerifyStreamingData(
        json: [String: Any],
        videoId: String,
        songDuration: TimeInterval,
        iosUA: String
    ) async throws -> ResolvedStream {
        guard let streamingData = json["streamingData"] as? [String: Any] else {
            let status = (json["playabilityStatus"] as? [String: Any])?["status"] as? String ?? "UNKNOWN"
            print("[StreamResolutionService] No streamingData found for \(videoId). Status: \(status)")
            throw StreamResolutionError.streamResolutionFailed
        }
        
        // 1. Check if Innertube genuinely returned hlsManifestUrl (HLS master playlist)
        if let hlsStr = streamingData["hlsManifestUrl"] as? String, let hlsURL = URL(string: hlsStr) {
            let host = hlsURL.host ?? "unknown"
            print("[StreamResolutionService] Innertube genuinely returned hlsManifestUrl host: \(host)")
            self.latestDiagnostic = StreamDiagnosticInfo(
                httpStatus: 200,
                contentType: "application/x-mpegURL",
                acceptRanges: "bytes",
                contentRange: "HLS Manifest",
                contentLength: "manifest",
                mimeType: "application/x-mpegURL",
                codec: "AAC (HLS)",
                bitrate: 0,
                urlHost: host
            )
            return ResolvedStream(
                url: hlsURL,
                isHLS: true,
                duration: songDuration,
                bitrate: nil,
                mimeType: "application/x-mpegURL",
                headers: nil
            )
        }
        
        // 2. Check for Adaptive Formats
        let adaptiveFormats = (streamingData["adaptiveFormats"] as? [[String: Any]]) ?? []
        var audioFormats = adaptiveFormats.filter { ($0["mimeType"] as? String)?.contains("audio") == true }
        
        // If none in adaptive, check standard formats
        if audioFormats.isEmpty {
            let formats = (streamingData["formats"] as? [[String: Any]]) ?? []
            audioFormats = formats.filter { ($0["mimeType"] as? String)?.contains("audio") == true }
        }
        
        if audioFormats.isEmpty {
            print("[StreamResolutionService] No audio formats found for \(videoId)")
            throw StreamResolutionError.noAudioFormat
        }
        
        // Sort: prioritize audio/mp4 (Apple native hardware AAC) over audio/webm, then by bitrate descending
        let sorted = audioFormats.sorted { f1, f2 in
            let mime1 = f1["mimeType"] as? String ?? ""
            let mime2 = f2["mimeType"] as? String ?? ""
            let isMp4_1 = mime1.contains("audio/mp4")
            let isMp4_2 = mime2.contains("audio/mp4")
            if isMp4_1 != isMp4_2 {
                return isMp4_1 && !isMp4_2
            }
            return (f1["bitrate"] as? Int ?? 0) > (f2["bitrate"] as? Int ?? 0)
        }
        
        var lastError: StreamResolutionError = .noAudioFormat
        
        for fmt in sorted {
            guard let urlStr = fmt["url"] as? String, let audioURL = URL(string: urlStr) else {
                continue
            }
            
            let mime = fmt["mimeType"] as? String ?? "unknown"
            let bitrate = fmt["bitrate"] as? Int ?? 0
            let durationMs = Double(fmt["approxDurationMs"] as? String ?? "0") ?? 0
            let host = audioURL.host ?? "unknown"
            
            // Extract audio codec from mimeType (e.g. audio/mp4; codecs="mp4a.40.2")
            var audioCodec = "unknown"
            if let range = mime.range(of: "codecs=\"") {
                let suffix = mime[range.upperBound...]
                if let endQuote = suffix.firstIndex(of: "\"") {
                    audioCodec = String(suffix[..<endQuote])
                }
            }
            
            // Preflight test DIRECT URL with URLSession Range: bytes=0-1023
            var testReq = URLRequest(url: audioURL)
            testReq.httpMethod = "GET"
            testReq.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
            testReq.setValue(iosUA, forHTTPHeaderField: "User-Agent")
            
            do {
                let (_, testResponse) = try await URLSession.shared.data(for: testReq)
                guard let httpResp = testResponse as? HTTPURLResponse else {
                    lastError = .streamResolutionFailed
                    continue
                }
                
                let statusCode = httpResp.statusCode
                let contentType = httpResp.value(forHTTPHeaderField: "Content-Type") ?? "none"
                let acceptRanges = httpResp.value(forHTTPHeaderField: "Accept-Ranges") ?? "none"
                let contentRange = httpResp.value(forHTTPHeaderField: "Content-Range") ?? "none"
                let contentLength = httpResp.value(forHTTPHeaderField: "Content-Length") ?? "none"
                
                self.latestDiagnostic = StreamDiagnosticInfo(
                    httpStatus: statusCode,
                    contentType: contentType,
                    acceptRanges: acceptRanges,
                    contentRange: contentRange,
                    contentLength: contentLength,
                    mimeType: mime,
                    codec: audioCodec,
                    bitrate: bitrate,
                    urlHost: host
                )
                
                print("""
                [StreamResolution] Audio Format Diagnostic:
                  mimeType: \(mime)
                  audio codec: \(audioCodec)
                  bitrate: \(bitrate)
                  URL host: \(host)
                  HTTP status: \(statusCode)
                  Content-Type: \(contentType)
                  Accept-Ranges: \(acceptRanges)
                  Content-Range: \(contentRange)
                """)
                
                if statusCode == 200 || statusCode == 206 {
                    let streamDuration = durationMs > 0 ? (durationMs / 1000.0) : songDuration
                    return ResolvedStream(
                        url: audioURL,
                        isHLS: false,
                        duration: streamDuration,
                        bitrate: bitrate,
                        mimeType: mime,
                        headers: nil
                    )
                } else if statusCode == 403 {
                    print("[StreamResolution] Direct stream URL test failed with HTTP 403 Forbidden!")
                    lastError = .http403
                } else {
                    print("[StreamResolution] Direct stream URL test returned HTTP \(statusCode)")
                    lastError = .httpStatus(statusCode)
                }
            } catch {
                print("[StreamResolution] Preflight network error: \(error)")
                lastError = .streamResolutionFailed
            }
        }
        
        throw lastError
    }
}
