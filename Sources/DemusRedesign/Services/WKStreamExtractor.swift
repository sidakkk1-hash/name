import Foundation
import WebKit
import Combine
import SwiftUI

// MARK: - WKStreamExtractorError
public enum WKStreamExtractorError: LocalizedError, Sendable {
    case invalidVideoId
    case timeout
    case extractionFailed(String)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .invalidVideoId:
            return "Invalid YouTube Video ID"
        case .timeout:
            return "Stream extraction timed out (15s)"
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"
        case .cancelled:
            return "Extraction cancelled for new track"
        }
    }
}

// MARK: - ExtractorDiagnostics
public struct ExtractorDiagnostics: Sendable {
    public var state: String = "idle" // idle, loading, found, failed
    public var host: String = "None"
    public var elapsedTime: Double = 0.0
    public var failure: String? = nil
}

// MARK: - WKStreamExtractor
/// Native Demus-style stream URL extractor using a background WKWebView.
/// Loads YouTube's mobile watch page, lets YouTube's own player resolve the media,
/// and extracts the deciphered video.currentSrc or hlsManifestUrl for native AVPlayer playback.
/// Never plays audio inside WebKit.
@Observable
@MainActor
public final class WKStreamExtractor: NSObject, WKNavigationDelegate, @unchecked Sendable {
    public static let shared = WKStreamExtractor()
    
    public var diagnostics = ExtractorDiagnostics()
    
    private var webView: WKWebView?
    private var currentExtractionTask: Task<URL, Error>?
    private var currentVideoId: String?
    
    override public init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = false
        config.allowsPictureInPictureMediaPlayback = false
        
        // CSS to hide all YouTube visual elements and mute media
        let userScript = WKUserScript(
            source: """
            (function() {
                var style = document.createElement('style');
                style.innerHTML = '#app, #header-bar, .mobile-topbar-header-background, .ghost-header { display: none !important; }';
                document.head.appendChild(style);
                
                // Keep media muted inside extraction context
                try {
                    var origDesc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'muted');
                    Object.defineProperty(HTMLMediaElement.prototype, 'muted', {
                        get: function() { return true; },
                        set: function() {},
                        configurable: true
                    });
                } catch(e) {}
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)
        
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 2, height: 2), configuration: config)
        wv.navigationDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.alpha = 0.01
        
        self.webView = wv
    }
    
    public func getWebView() -> WKWebView? {
        return self.webView
    }
    
    // MARK: - Extract Stream URL
    public func extractStreamURL(for videoId: String) async throws -> URL {
        guard !videoId.isEmpty else {
            throw WKStreamExtractorError.invalidVideoId
        }
        
        // Cancel any pending extraction
        currentExtractionTask?.cancel()
        
        let task = Task<URL, Error> { @MainActor in
            self.currentVideoId = videoId
            self.diagnostics.state = "loading"
            self.diagnostics.host = "m.youtube.com"
            self.diagnostics.elapsedTime = 0
            self.diagnostics.failure = nil
            
            let startTime = Date()
            guard let wv = self.webView else {
                self.diagnostics.state = "failed"
                self.diagnostics.failure = "Extractor webView uninitialized"
                throw WKStreamExtractorError.extractionFailed("WebView uninitialized")
            }
            
            guard let watchURL = URL(string: "https://m.youtube.com/watch?v=\(videoId)") else {
                self.diagnostics.state = "failed"
                self.diagnostics.failure = "Invalid URL"
                throw WKStreamExtractorError.invalidVideoId
            }
            
            print("[WKStreamExtractor] Loading watch page for videoId: \(videoId)")
            var request = URLRequest(url: watchURL)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            wv.load(request)
            
            // Poll for resolved media URL every 350ms up to 15 seconds
            let pollInterval: UInt64 = 350_000_000 // 350ms
            let maxAttempts = 43 // ~15 seconds total
            
            let extractionJS = """
            (() => {
                // 1. Check video tag for resolved media source
                let v = document.querySelector("video");
                if (v) {
                    let s = v.currentSrc || v.src;
                    if (s && s.length > 10 && !s.startsWith("blob:") && !s.startsWith("data:") && !s.includes("/watch?")) {
                        return { source: "video", url: s };
                    }
                }
                
                // 2. Check ytInitialPlayerResponse streamingData for hlsManifestUrl or direct format
                try {
                    if (window.ytInitialPlayerResponse && window.ytInitialPlayerResponse.streamingData) {
                        let sd = window.ytInitialPlayerResponse.streamingData;
                        if (sd.hlsManifestUrl && !sd.hlsManifestUrl.startsWith("blob:")) {
                            return { source: "hlsManifestUrl", url: sd.hlsManifestUrl };
                        }
                        if (sd.formats && sd.formats.length > 0 && sd.formats[0].url) {
                            let fu = sd.formats[0].url;
                            if (fu && !fu.startsWith("blob:")) {
                                return { source: "formats[0]", url: fu };
                            }
                        }
                    }
                } catch(e) {}
                
                return null;
            })()
            """
            
            for attempt in 0..<maxAttempts {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: pollInterval)
                try Task.checkCancellation()
                
                let elapsed = Date().timeIntervalSince(startTime)
                self.diagnostics.elapsedTime = elapsed
                
                do {
                    let result = try await wv.evaluateJavaScript(extractionJS)
                    if let dict = result as? [String: Any],
                       let urlStr = dict["url"] as? String,
                       let resolvedURL = URL(string: urlStr),
                       let host = resolvedURL.host,
                       !urlStr.hasPrefix("blob:"),
                       !urlStr.hasPrefix("data:"),
                       !urlStr.contains("/watch?") {
                        
                        // Valid stream URL extracted!
                        // Immediately stop and mute the webview so it never outputs audio
                        wv.evaluateJavaScript("""
                        try {
                            let v = document.querySelector("video");
                            if (v) { v.pause(); v.src = ""; }
                            window.stop();
                        } catch(e) {}
                        """, completionHandler: nil)
                        
                        self.diagnostics.state = "found"
                        self.diagnostics.host = host
                        self.diagnostics.elapsedTime = elapsed
                        self.diagnostics.failure = nil
                        
                        // Log only host and duration — NEVER full signed URL
                        let srcType = dict["source"] as? String ?? "unknown"
                        print("[WKStreamExtractor] Stream found via \(srcType) in \(String(format: "%.2f", elapsed))s | Host: \(host)")
                        return resolvedURL
                    }
                } catch {
                    // Ignore interim evaluation errors while page loads
                }
            }
            
            // 15 seconds elapsed without resolving stream
            wv.stopLoading()
            self.diagnostics.state = "failed"
            self.diagnostics.failure = "Stream extraction timed out after 15s"
            print("[WKStreamExtractor] Extraction timed out for videoId: \(videoId)")
            throw WKStreamExtractorError.timeout
        }
        
        self.currentExtractionTask = task
        return try await task.value
    }
    
    public func cancel() {
        currentExtractionTask?.cancel()
        currentExtractionTask = nil
        webView?.stopLoading()
        webView?.evaluateJavaScript("""
        try {
            let v = document.querySelector("video");
            if (v) { v.pause(); v.src = ""; }
            window.stop();
        } catch(e) {}
        """, completionHandler: nil)
        diagnostics.state = "idle"
    }
}

// MARK: - WKStreamExtractorView (Representable)
/// Hidden 1x1 view representable ensuring WebKit view hierarchy prioritization for the extractor
public struct WKStreamExtractorView: UIViewRepresentable {
    public init() {}
    
    public func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        container.backgroundColor = .clear
        container.alpha = 0.01
        container.isUserInteractionEnabled = false
        if let wv = WKStreamExtractor.shared.getWebView() {
            container.addSubview(wv)
        }
        return container
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
}
