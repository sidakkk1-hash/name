import Foundation
import WebKit
import Combine
import CoreGraphics
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@preconcurrency import AVFoundation

// MARK: - WKAudioEngineDelegate
public protocol WKAudioEngineDelegate: AnyObject, Sendable {
    func audioEngineDidReady()
    func audioEngineDidChangeState(isPlaying: Bool, isLoading: Bool)
    func audioEngineDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval)
    func audioEngineDidEnd()
    func audioEngineDidFail(error: String)
}

// MARK: - WKDiagnostics
public struct WKDiagnostics: Sendable {
    public var isWebViewAlive: Bool = false
    public var isPlayerReady: Bool = false
    public var youtubeState: String = "Unstarted"
    public var audioAnchorStatus: String = "Stopped"
    public var webAudioSessionAvailable: Bool = false
    public var webAudioSessionType: String = "unknown"
    public var documentHidden: Bool = false
    public var documentVisibilityState: String = "visible"
    public var mediaSessionAvailable: Bool = false
    public var lastYouTubeError: String = "None"
    public var lastWebKitError: String = "None"
}

// MARK: - WKAudioEngine
/// WebKit-powered background YouTube audio engine recreating Demus's battle-tested
/// EmbedPlayer architecture with silent audio anchoring, WebKit AudioSession playback type,
/// visibility state protection, and MediaSession integration.
@Observable
@MainActor
public final class WKAudioEngine: NSObject, WKScriptMessageHandler, WKNavigationDelegate, @unchecked Sendable {
    public static let shared = WKAudioEngine()
    
    public weak var delegate: WKAudioEngineDelegate?
    
    public var diagnostics = WKDiagnostics()
    
    private var webView: WKWebView?
    private var isPlayerReady: Bool = false
    private var currentVideoId: String?
    private var lastLoadedMetadata: (title: String, artist: String, album: String, artworkUrl: String, duration: TimeInterval)?
    
    override public init() {
        super.init()
        setupAudioSession()
        setupWebView()
    }
    
    // MARK: - Native Audio Session Setup
    private func setupAudioSession() {
        #if canImport(AVFAudio)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
            try session.setActive(true)
            print("[WKAudioEngine] AVAudioSession configured: .playback, active=true")
        } catch {
            print("[WKAudioEngine] AVAudioSession setup error:", error)
        }
        #endif
    }
    
    // MARK: - WebKit Initialization
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        
        // Ensure web preferences allow background audio processing
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "audioBridge")
        config.userContentController = contentController
        
        // Non-zero minimal frame to ensure WebKit rendering engine remains active
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 2, height: 2), configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.alpha = 0.01
        wv.navigationDelegate = self
        
        self.webView = wv
        self.diagnostics.isWebViewAlive = true
        loadPlayerHTML()
    }
    
    private func loadPlayerHTML() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        body, html { margin:0; padding:0; width:100%; height:100%; overflow:hidden; background-color:#000; }
        #player { width:100%; height:100%; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
        // --- 1. Silent Audio Anchor ---
        // Loops an in-memory silent MP3 buffer to keep WebKit audio process continuously active in background
        var audioSource = "data:audio/mp3;base64, /+MYxAAAAANIAAAAAExBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxDsAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxHYAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxLEAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV";
        var silentAnchor = new Audio(audioSource);
        silentAnchor.loop = true;
        var anchorActive = false;

        function send(msg) {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.audioBridge) {
                    window.webkit.messageHandlers.audioBridge.postMessage(msg);
                }
            } catch(e) {}
        }

        function startSilentAnchor() {
            if (!anchorActive && silentAnchor) {
                silentAnchor.play().then(function() {
                    anchorActive = true;
                    send({event: "audioAnchor", status: "Playing"});
                }).catch(function(e) {
                    send({event: "audioAnchor", status: "Failed: " + e.message});
                });
            }
        }

        function stopSilentAnchor() {
            if (silentAnchor) {
                try { silentAnchor.pause(); } catch(e) {}
                anchorActive = false;
                send({event: "audioAnchor", status: "Stopped"});
            }
        }

        // --- 2. Visibility Handling & Background Protection ---
        // Prevents player from auto-pausing when screen locks or app backgrounds
        function protectVisibility(w) {
            try {
                if (w && w.document) {
                    Object.defineProperty(w.document, 'hidden', { get: () => false, configurable: true });
                    Object.defineProperty(w.document, 'visibilityState', { get: () => 'visible', configurable: true });
                    w.document.addEventListener('visibilitychange', function(e) {
                        e.stopImmediatePropagation();
                        send({event: "visibilityStatus", hidden: false, state: "visible"});
                    }, true);
                    w.addEventListener('pagehide', function(e) {
                        e.stopImmediatePropagation();
                    }, true);
                    send({event: "visibilityStatus", hidden: false, state: "visible"});
                }
            } catch(e) {}
        }
        protectVisibility(window);

        // --- 3. WebKit AudioSession API (Feature-detected) ---
        function applyWebAudioSession(w) {
            if (w && w.navigator && ("audioSession" in w.navigator)) {
                try {
                    w.navigator.audioSession.type = "playback";
                    send({event: "audioSessionConfig", available: true, type: w.navigator.audioSession.type});
                } catch(e) {
                    send({event: "audioSessionConfig", available: true, type: "error: " + e.message});
                }
            } else {
                send({event: "audioSessionConfig", available: false, type: "unavailable"});
            }
        }
        applyWebAudioSession(window);

        // --- 4. Web MediaSession Handlers ---
        function setupMediaSession(w) {
            if (w && w.navigator && ("mediaSession" in w.navigator)) {
                try {
                    var ms = w.navigator.mediaSession;
                    ms.setActionHandler("play", function() { send({event: "ms_play"}); });
                    ms.setActionHandler("pause", function() { send({event: "ms_pause"}); });
                    ms.setActionHandler("previoustrack", function() { send({event: "ms_prev"}); });
                    ms.setActionHandler("nexttrack", function() { send({event: "ms_next"}); });
                    ms.setActionHandler("seekto", function(details) {
                        send({event: "ms_seek", time: details.seekTime});
                    });
                    send({event: "mediaSessionStatus", available: true});
                } catch(e) {
                    send({event: "mediaSessionStatus", available: false});
                }
            } else {
                send({event: "mediaSessionStatus", available: false});
            }
        }
        setupMediaSession(window);

        // --- 5. YouTube IFrame API Initialization ---
        var tag = document.createElement('script');
        tag.src = "https://www.youtube.com/iframe_api";
        var firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

        var player;
        var playerWindow = null;
        var isReady = false;
        var pendingId = null;

        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                height: '100%',
                width: '100%',
                playerVars: {
                    'playsinline': 1,
                    'controls': 0,
                    'disablekb': 1,
                    'fs': 0,
                    'rel': 0,
                    'modestbranding': 1,
                    'autoplay': 1,
                    'origin': 'https://www.youtube-nocookie.com'
                },
                events: {
                    'onReady': onPlayerReady,
                    'onStateChange': onPlayerStateChange,
                    'onError': onPlayerError
                }
            });
        }

        function onPlayerReady(event) {
            isReady = true;
            try {
                var iframe = document.getElementById("player");
                if (iframe && iframe.contentWindow) {
                    playerWindow = iframe.contentWindow;
                    protectVisibility(playerWindow);
                    applyWebAudioSession(playerWindow);
                    setupMediaSession(playerWindow);
                }
            } catch(e) {}

            send({event: 'ready'});
            if (pendingId) {
                player.loadVideoById(pendingId);
                pendingId = null;
            }
        }

        function onPlayerStateChange(event) {
            var cur = (player && player.getCurrentTime) ? player.getCurrentTime() : 0;
            var dur = (player && player.getDuration) ? player.getDuration() : 0;
            
            // If playing (1), ensure silent anchor is engaged to keep WebKit audio process alive
            if (event.data === 1) {
                startSilentAnchor();
            } else if (event.data === 2 || event.data === 0) {
                stopSilentAnchor();
            }

            send({
                event: 'stateChange',
                state: event.data,
                currentTime: cur,
                duration: dur
            });
        }

        function onPlayerError(event) {
            send({
                event: 'error',
                code: event.data
            });
        }

        function loadVideo(id) {
            if (isReady && player && player.loadVideoById) {
                player.loadVideoById(id);
                startSilentAnchor();
            } else {
                pendingId = id;
            }
        }

        function playVideo() {
            if (player && player.playVideo) {
                player.playVideo();
                startSilentAnchor();
            }
        }

        function pauseVideo() {
            if (player && player.pauseVideo) {
                player.pauseVideo();
                stopSilentAnchor();
            }
        }

        function seekTo(sec) {
            if (player && player.seekTo) {
                player.seekTo(sec, true);
            }
        }

        function setVolume(val) {
            if (player && player.setVolume) {
                player.setVolume(val);
            }
        }

        function setMediaMetadata(title, artist, album, artworkUrl, duration) {
            for (var w of [window, playerWindow]) {
                if (w && w.navigator && ("mediaSession" in w.navigator)) {
                    try {
                        w.navigator.mediaSession.metadata = new MediaMetadata({
                            title: title,
                            artist: artist,
                            album: album,
                            artwork: artworkUrl ? [{ src: artworkUrl, sizes: "512x512", type: "image/jpeg" }] : []
                        });
                        if (duration > 0 && w.navigator.mediaSession.setPositionState) {
                            w.navigator.mediaSession.setPositionState({ duration: duration });
                        }
                    } catch(e) {}
                }
            }
        }

        // Periodic time updates
        setInterval(function() {
            if (player && isReady && player.getPlayerState && player.getPlayerState() === 1) {
                var cur = player.getCurrentTime() || 0;
                var dur = player.getDuration() || 0;
                send({
                    event: 'timeUpdate',
                    currentTime: cur,
                    duration: dur
                });
            }
        }, 500);
        </script>
        </body>
        </html>
        """
        
        webView?.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }
    
    // MARK: - Playback Controls
    public func loadAndPlay(videoId: String, title: String = "", artist: String = "", album: String = "", artworkUrl: String = "", duration: TimeInterval = 0) {
        self.currentVideoId = videoId
        self.lastLoadedMetadata = (title, artist, album, artworkUrl, duration)
        let escapedId = videoId.replacingOccurrences(of: "'", with: "\\'")
        let escapedTitle = title.replacingOccurrences(of: "'", with: "\\'")
        let escapedArtist = artist.replacingOccurrences(of: "'", with: "\\'")
        let escapedAlbum = album.replacingOccurrences(of: "'", with: "\\'")
        let escapedArtwork = artworkUrl.replacingOccurrences(of: "'", with: "\\'")
        
        let js = """
        loadVideo('\(escapedId)');
        setMediaMetadata('\(escapedTitle)', '\(escapedArtist)', '\(escapedAlbum)', '\(escapedArtwork)', \(duration));
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    public func play() {
        webView?.evaluateJavaScript("playVideo();", completionHandler: nil)
    }
    
    public func pause() {
        webView?.evaluateJavaScript("pauseVideo();", completionHandler: nil)
    }
    
    public func seek(to seconds: TimeInterval) {
        let js = "seekTo(\(seconds));"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    public func setVolume(_ volume: Double) {
        let clamped = max(0, min(volume, 1.0))
        let intVol = Int(clamped * 100)
        let js = "setVolume(\(intVol));"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.diagnostics.lastWebKitError = error.localizedDescription
        print("[WKAudioEngine] WebKit navigation failed: \(error)")
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.diagnostics.lastWebKitError = error.localizedDescription
        print("[WKAudioEngine] WebKit provisional navigation failed: \(error)")
    }
    
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print("[WKAudioEngine] WebContent process terminated! Reloading player...")
        self.diagnostics.lastWebKitError = "WebContent process terminated (Reloading)"
        self.diagnostics.isPlayerReady = false
        loadPlayerHTML()
        if let videoId = currentVideoId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if let meta = self.lastLoadedMetadata {
                    self.loadAndPlay(videoId: videoId, title: meta.title, artist: meta.artist, album: meta.album, artworkUrl: meta.artworkUrl, duration: meta.duration)
                } else {
                    self.loadAndPlay(videoId: videoId)
                }
            }
        }
    }
    
    // MARK: - WKScriptMessageHandler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let event = dict["event"] as? String else { return }
        
        switch event {
        case "ready":
            self.isPlayerReady = true
            self.diagnostics.isPlayerReady = true
            delegate?.audioEngineDidReady()
            
        case "stateChange":
            if let state = dict["state"] as? Int {
                // -1 = unstarted, 0 = ended, 1 = playing, 2 = paused, 3 = buffering, 5 = cued
                let stateStr: String
                switch state {
                case -1: stateStr = "Unstarted (-1)"
                case 0: stateStr = "Ended (0)"
                case 1: stateStr = "Playing (1)"
                case 2: stateStr = "Paused (2)"
                case 3: stateStr = "Buffering (3)"
                case 5: stateStr = "Video Cued (5)"
                default: stateStr = "State \(state)"
                }
                self.diagnostics.youtubeState = stateStr
                
                let isPlaying = (state == 1)
                let isLoading = (state == 3 || state == -1)
                
                let cur = dict["currentTime"] as? Double ?? 0
                let dur = dict["duration"] as? Double ?? 0
                if dur > 0 {
                    delegate?.audioEngineDidUpdateTime(currentTime: cur, duration: dur)
                }
                
                if state == 0 {
                    delegate?.audioEngineDidEnd()
                } else {
                    delegate?.audioEngineDidChangeState(isPlaying: isPlaying, isLoading: isLoading)
                }
            }
            
        case "timeUpdate":
            let cur = dict["currentTime"] as? Double ?? 0
            let dur = dict["duration"] as? Double ?? 0
            delegate?.audioEngineDidUpdateTime(currentTime: cur, duration: dur)
            
        case "audioAnchor":
            let status = dict["status"] as? String ?? "Unknown"
            self.diagnostics.audioAnchorStatus = status
            
        case "audioSessionConfig":
            let available = dict["available"] as? Bool ?? false
            let type = dict["type"] as? String ?? "unknown"
            self.diagnostics.webAudioSessionAvailable = available
            self.diagnostics.webAudioSessionType = type
            
        case "visibilityStatus":
            let hidden = dict["hidden"] as? Bool ?? false
            let state = dict["state"] as? String ?? "visible"
            self.diagnostics.documentHidden = hidden
            self.diagnostics.documentVisibilityState = state
            
        case "mediaSessionStatus":
            let available = dict["available"] as? Bool ?? false
            self.diagnostics.mediaSessionAvailable = available
            
        case "ms_play":
            PlayerEngine.shared.playFromWebMediaSession()
            
        case "ms_pause":
            PlayerEngine.shared.pauseFromWebMediaSession()
            
        case "ms_next":
            PlayerEngine.shared.next()
            
        case "ms_prev":
            PlayerEngine.shared.previous()
            
        case "ms_seek":
            if let sec = dict["time"] as? Double {
                PlayerEngine.shared.seek(to: sec)
            }
            
        case "error":
            let code = dict["code"] as? Int ?? -1
            let errStr: String
            switch code {
            case 2: errStr = "Invalid video parameter (2)"
            case 5: errStr = "HTML5 player error (5)"
            case 100: errStr = "Video not found or removed (100)"
            case 101, 150: errStr = "Embedding restricted by owner (\(code))"
            default: errStr = "Player error (\(code))"
            }
            self.diagnostics.lastYouTubeError = errStr
            delegate?.audioEngineDidFail(error: errStr)
            
        default:
            break
        }
    }
    
    public func getWebView() -> WKWebView? {
        return self.webView
    }
}

// MARK: - WKAudioEngineView Representable
#if canImport(UIKit)
import SwiftUI

public struct WKAudioEngineView: UIViewRepresentable {
    public init() {}
    
    public func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        container.isHidden = true
        if let wv = WKAudioEngine.shared.getWebView() {
            container.addSubview(wv)
        }
        return container
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
