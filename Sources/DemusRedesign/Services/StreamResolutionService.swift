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
        public let expireTimestamp: String?
        
        public init(
            httpStatus: Int,
            contentType: String,
            acceptRanges: String,
            contentRange: String,
            contentLength: String,
            mimeType: String,
            codec: String,
            bitrate: Int,
            urlHost: String,
            expireTimestamp: String? = nil
        ) {
            self.httpStatus = httpStatus
            self.contentType = contentType
            self.acceptRanges = acceptRanges
            self.contentRange = contentRange
            self.contentLength = contentLength
            self.mimeType = mimeType
            self.codec = codec
            self.bitrate = bitrate
            self.urlHost = urlHost
            self.expireTimestamp = expireTimestamp
        }
    }
    
    public struct HLSDiagnosticInfo: Sendable {
        public let sidxValid: Bool
        public let segmentCount: Int
        public let initRange: String
        public let indexRange: String
        public let targetDuration: Int
        public let playlistGenerated: Bool
        public let firstMediaRange: String
        public let lastMediaRange: String
        public let totalDuration: Double
        public let serverURL: String?
        public let failureReason: String?
        
        public init(
            sidxValid: Bool,
            segmentCount: Int,
            initRange: String,
            indexRange: String,
            targetDuration: Int,
            playlistGenerated: Bool,
            firstMediaRange: String,
            lastMediaRange: String,
            totalDuration: Double,
            serverURL: String? = nil,
            failureReason: String? = nil
        ) {
            self.sidxValid = sidxValid
            self.segmentCount = segmentCount
            self.initRange = initRange
            self.indexRange = indexRange
            self.targetDuration = targetDuration
            self.playlistGenerated = playlistGenerated
            self.firstMediaRange = firstMediaRange
            self.lastMediaRange = lastMediaRange
            self.totalDuration = totalDuration
            self.serverURL = serverURL
            self.failureReason = failureReason
        }
    }
    
    public private(set) var latestDiagnostic: StreamDiagnosticInfo?
    public private(set) var latestHLSDiagnostic: HLSDiagnosticInfo?
    
    // MARK: - SIDX Parser (ISO/IEC 14496-12)
    public struct SIDXParser {
        public struct Segment: Sendable {
            public let length: Int
            public let offset: Int
            public let duration: Double
        }
        
        public static func parse(data: Data, indexEnd: Int, contentLength: Int) throws -> (timescale: Int, segments: [Segment], targetDuration: Int) {
            guard data.count >= 32 else {
                throw NSError(domain: "SIDXParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "SIDX data too small: \(data.count) bytes"])
            }
            
            func readUInt32(_ offset: Int) -> UInt32 {
                let b0 = UInt32(data[offset])
                let b1 = UInt32(data[offset + 1])
                let b2 = UInt32(data[offset + 2])
                let b3 = UInt32(data[offset + 3])
                return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
            }
            
            func readUInt16(_ offset: Int) -> UInt16 {
                let b0 = UInt16(data[offset])
                let b1 = UInt16(data[offset + 1])
                return (b0 << 8) | b1
            }
            
            func readUInt64(_ offset: Int) -> UInt64 {
                let hi = UInt64(readUInt32(offset))
                let lo = UInt64(readUInt32(offset + 4))
                return (hi << 32) | lo
            }
            
            let boxTypeBytes = [data[4], data[5], data[6], data[7]]
            let boxTypeStr = String(bytes: boxTypeBytes, encoding: .ascii) ?? ""
            guard boxTypeStr == "sidx" else {
                throw NSError(domain: "SIDXParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Box type is '\(boxTypeStr)', expected 'sidx'"])
            }
            
            let version = data[8]
            let timescale = Int(readUInt32(16))
            guard timescale > 0 else {
                throw NSError(domain: "SIDXParser", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid timescale: \(timescale)"])
            }
            
            var offset = 20
            var firstOffset: Int = 0
            if version == 0 {
                offset += 4 // earliest_presentation_time
                firstOffset = Int(readUInt32(offset))
                offset += 4
            } else {
                offset += 8 // earliest_presentation_time
                firstOffset = Int(readUInt64(offset))
                offset += 8
            }
            
            offset += 2 // reserved
            let referenceCount = Int(readUInt16(offset))
            offset += 2
            
            guard referenceCount > 0 else {
                throw NSError(domain: "SIDXParser", code: 4, userInfo: [NSLocalizedDescriptionKey: "Reference count is 0"])
            }
            
            guard data.count >= offset + (referenceCount * 12) else {
                throw NSError(domain: "SIDXParser", code: 5, userInfo: [NSLocalizedDescriptionKey: "SIDX truncated: expected \(offset + (referenceCount * 12)) bytes, got \(data.count)"])
            }
            
            let firstMediaOffset = indexEnd + 1 + firstOffset
            var currOffset = firstMediaOffset
            var segments: [Segment] = []
            var maxDur: Double = 0.0
            
            for i in 0..<referenceCount {
                let refOff = offset + (i * 12)
                let info = readUInt32(refOff)
                let subDuration = readUInt32(refOff + 4)
                
                let refType = (info >> 31) & 0x01
                guard refType == 0 else {
                    throw NSError(domain: "SIDXParser", code: 6, userInfo: [NSLocalizedDescriptionKey: "Reference \(i) has nested sidx (ref_type = 1)"])
                }
                
                let refSize = Int(info & 0x7FFFFFFF)
                let durSec = Double(subDuration) / Double(timescale)
                if durSec > maxDur { maxDur = durSec }
                
                guard currOffset + refSize <= contentLength else {
                    throw NSError(domain: "SIDXParser", code: 7, userInfo: [NSLocalizedDescriptionKey: "Segment \(i) (range \(currOffset)-\(currOffset + refSize)) exceeds contentLength \(contentLength)"])
                }
                
                segments.append(Segment(length: refSize, offset: currOffset, duration: durSec))
                currOffset += refSize
            }
            
            let targetDuration = max(1, Int(ceil(maxDur)))
            return (timescale, segments, targetDuration)
        }
    }
    
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
                    let expireParam = URLComponents(url: audioURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "expire" })?.value
                    
                    self.latestDiagnostic = StreamDiagnosticInfo(
                        httpStatus: statusCode,
                        contentType: contentType,
                        acceptRanges: acceptRanges,
                        contentRange: contentRange,
                        contentLength: contentLength,
                        mimeType: mime,
                        codec: audioCodec,
                        bitrate: bitrate,
                        urlHost: host,
                        expireTimestamp: expireParam
                    )
                    
                    // Attempt Option A: SIDX-based HLS playlist generation
                    if let initRangeDict = fmt["initRange"] as? [String: Any],
                       let indexRangeDict = fmt["indexRange"] as? [String: Any],
                       let initStartStr = initRangeDict["start"] as? String,
                       let initEndStr = initRangeDict["end"] as? String,
                       let idxStartStr = indexRangeDict["start"] as? String,
                       let idxEndStr = indexRangeDict["end"] as? String,
                       let initStart = Int(initStartStr),
                       let initEnd = Int(initEndStr),
                       let idxStart = Int(idxStartStr),
                       let idxEnd = Int(idxEndStr) {
                        
                        let cLen = Int(fmt["contentLength"] as? String ?? "0") ?? 0
                        
                        print("""
                        [StreamResolution] SIDX Preflight:
                          host: \(host)
                          initRange: \(initStart)-\(initEnd)
                          indexRange: \(idxStart)-\(idxEnd)
                          contentLength: \(cLen)
                          expire: \(expireParam ?? "none")
                        """)
                        
                        do {
                            var sidxReq = URLRequest(url: audioURL)
                            sidxReq.httpMethod = "GET"
                            sidxReq.setValue("bytes=\(idxStart)-\(idxEnd)", forHTTPHeaderField: "Range")
                            sidxReq.setValue(iosUA, forHTTPHeaderField: "User-Agent")
                            
                            let (sidxData, sidxResp) = try await URLSession.shared.data(for: sidxReq)
                            guard let sidxHttp = sidxResp as? HTTPURLResponse, (sidxHttp.statusCode == 200 || sidxHttp.statusCode == 206) else {
                                let code = (sidxResp as? HTTPURLResponse)?.statusCode ?? -1
                                throw NSError(domain: "SIDXFetch", code: code, userInfo: [NSLocalizedDescriptionKey: "SIDX fetch returned HTTP \(code)"])
                            }
                            
                            let (timescale, segments, targetDuration) = try SIDXParser.parse(data: sidxData, indexEnd: idxEnd, contentLength: cLen)
                            
                            // Validate playlist syntax (Rule 9)
                            let initLen = initEnd - initStart + 1
                            guard !segments.isEmpty else {
                                throw NSError(domain: "HLSValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Segment list is empty"])
                            }
                            
                            for i in 0..<segments.count {
                                let seg = segments[i]
                                guard seg.duration <= Double(targetDuration) + 0.001 else {
                                    throw NSError(domain: "HLSValidation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Segment \(i) duration \(seg.duration)s exceeds TARGETDURATION \(targetDuration)s"])
                                }
                                guard seg.offset + seg.length <= cLen else {
                                    throw NSError(domain: "HLSValidation", code: 3, userInfo: [NSLocalizedDescriptionKey: "Segment \(i) range exceeds contentLength \(cLen)"])
                                }
                                if i > 0 {
                                    let prev = segments[i - 1]
                                    guard prev.offset + prev.length == seg.offset else {
                                        throw NSError(domain: "HLSValidation", code: 5, userInfo: [NSLocalizedDescriptionKey: "Segment \(i) offset \(seg.offset) does not immediately follow segment \(i - 1) end \(prev.offset + prev.length)"])
                                    }
                                }
                            }
                            
                            let lastSeg = segments.last!
                            guard lastSeg.offset + lastSeg.length == cLen else {
                                throw NSError(domain: "HLSValidation", code: 4, userInfo: [NSLocalizedDescriptionKey: "Last segment end \(lastSeg.offset + lastSeg.length) does not match contentLength \(cLen)"])
                            }
                            
                            // Generate HLS playlist string
                            var m3u8Lines = [
                                "#EXTM3U",
                                "#EXT-X-VERSION:7",
                                "#EXT-X-TARGETDURATION:\(targetDuration)",
                                "#EXT-X-MEDIA-SEQUENCE:0",
                                "#EXT-X-PLAYLIST-TYPE:VOD",
                                "#EXT-X-MAP:URI=\"\(audioURL.absoluteString)\",BYTERANGE=\"\(initLen)@\(initStart)\""
                            ]
                            
                            for seg in segments {
                                m3u8Lines.append(String(format: "#EXTINF:%.5f,", seg.duration))
                                m3u8Lines.append("#EXT-X-BYTERANGE:\(seg.length)@\(seg.offset)")
                                m3u8Lines.append(audioURL.absoluteString)
                            }
                            m3u8Lines.append("#EXT-X-ENDLIST")
                            let m3u8Content = m3u8Lines.joined(separator: "\n")
                            
                            let tempDir = FileManager.default.temporaryDirectory
                            let m3u8URL = tempDir.appendingPathComponent("demus_\(videoId).m3u8")
                            try m3u8Content.write(to: m3u8URL, atomically: true, encoding: .utf8)
                            
                            // Serve via embedded loopback HTTP server to bypass Apple's file:// remote segment restriction
                            let port = try await LocalHLSServer.shared.ensureStarted()
                            LocalHLSServer.shared.setPlaylist(content: m3u8Content)
                            let httpPlaylistURL = URL(string: "http://127.0.0.1:\(port)/playlist.m3u8")!
                            
                            let totalDur = segments.reduce(0.0) { $0 + $1.duration }
                            let firstMediaRange = "\(segments[0].length)@\(segments[0].offset)"
                            let lastMediaRange = "\(lastSeg.length)@\(lastSeg.offset)"
                            
                            self.latestHLSDiagnostic = HLSDiagnosticInfo(
                                sidxValid: true,
                                segmentCount: segments.count,
                                initRange: "\(initLen)@\(initStart)",
                                indexRange: "\(idxStart)-\(idxEnd)",
                                targetDuration: targetDuration,
                                playlistGenerated: true,
                                firstMediaRange: firstMediaRange,
                                lastMediaRange: lastMediaRange,
                                totalDuration: totalDur,
                                serverURL: "http://127.0.0.1:\(port)/playlist.m3u8",
                                failureReason: nil
                            )
                            
                            print("""
                            [StreamResolution] HLS Generated & Served via LocalHLSServer:
                              serverURL: http://127.0.0.1:\(port)/playlist.m3u8
                              timescale: \(timescale)
                              segments: \(segments.count)
                              targetDuration: \(targetDuration)
                              initRange: \(initLen)@\(initStart)
                              firstMediaRange: \(firstMediaRange)
                              lastMediaRange: \(lastMediaRange)
                              totalDuration: \(totalDur)s
                            """)
                            
                            return ResolvedStream(
                                url: httpPlaylistURL,
                                isHLS: true,
                                duration: totalDur > 0 ? totalDur : streamDuration,
                                bitrate: bitrate,
                                mimeType: "application/x-mpegURL",
                                headers: nil
                            )
                        } catch {
                            print("[StreamResolution] SIDX parse/HLS generation error: \(error)")
                            self.latestHLSDiagnostic = HLSDiagnosticInfo(
                                sidxValid: false,
                                segmentCount: 0,
                                initRange: "\(initStart)-\(initEnd)",
                                indexRange: "\(idxStart)-\(idxEnd)",
                                targetDuration: 0,
                                playlistGenerated: false,
                                firstMediaRange: "none",
                                lastMediaRange: "none",
                                totalDuration: 0,
                                failureReason: error.localizedDescription
                            )
                            // Abort native playback if validation fails (Rule 1)
                            throw StreamResolutionError.streamResolutionFailed
                        }
                    }
                    
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
