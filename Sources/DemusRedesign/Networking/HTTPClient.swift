import Foundation

// MARK: - HTTPClient
/// Asynchronous HTTP client configured with YouTube Music Innertube payloads and headers.
public final class HTTPClient: @unchecked Sendable {
    public static let shared = HTTPClient()
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Innertube Context Payload
    public static func makeYTMContext() -> [String: Any] {
        return [
            "client": [
                "clientName": "WEB_REMIX",
                "clientVersion": "1.20250519.03.01",
                "hl": Locale.current.language.languageCode?.identifier ?? "en",
                "gl": Locale.current.region?.identifier ?? "US",
                "utcOffsetMinutes": TimeZone.current.secondsFromGMT() / 60
            ]
        ]
    }
    
    public static func makeIOSContext() -> [String: Any] {
        return [
            "client": [
                "clientName": "IOS",
                "clientVersion": "20.25.4",
                "deviceModel": "iPhone17,1",
                "userAgent": "com.google.ios.youtube/20.25.4 (iPhone17,1; U; CPU iOS 18_5 like Mac OS X)",
                "hl": "en",
                "gl": "US"
            ]
        ]
    }
    
    // MARK: - Generic POST Request with Innertube Payload
    public func postJSON(urlString: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return json
        }
        
        return [:]
    }
    
    // MARK: - Generic GET Request
    public func get(url: URL, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        if request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
