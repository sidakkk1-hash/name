import Foundation
import WebKit
import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFAudio)
import AVFAudio
#endif

// MARK: - WKEmbedAudioEngineDelegate
public protocol WKEmbedAudioEngineDelegate: AnyObject, Sendable {
    func embedAudioEngineDidReady()
    func embedAudioEngineDidChangeState(isPlaying: Bool, isLoading: Bool)
    func embedAudioEngineDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval)
    func embedAudioEngineDidEnd()
    func embedAudioEngineDidFail(error: String)
    func embedAudioEngineDidRequestNext()
    func embedAudioEngineDidRequestPrev()
}

// MARK: - EmbedPlayerDiagnostics
public struct EmbedPlayerDiagnostics: Sendable {
    public var webViewLoaded: Bool = false
    public var playerReady: Bool = false
    public var playerState: String = "unstarted" // unstarted, playing, paused, buffering, ended
    public var playerCurrentTime: Double = 0.0
    public var playerDuration: Double = 0.0
    public var playerRate: Float = 1.0
    public var playerError: String = "None"
    public var appState: String = "active"
    public var audioSessionCategory: String = "playback"
    public var audioSessionActive: Bool = false
    public var lastStateBeforeBackground: String = "None"
    public var firstStateAfterForeground: String = "None"
}

// MARK: - WKEmbedAudioEngine
/// Authentic Demus-style WebKit Embed Audio Engine.
/// Uses YouTube's official iframe API player with Demus's exact mediaSession and background configuration,
/// functioning as the sole audio playback engine without signed stream URL extraction or external AVPlayer.
@Observable
@MainActor
public final class WKEmbedAudioEngine: NSObject, WKScriptMessageHandler, WKNavigationDelegate, @unchecked Sendable {
    public static let shared = WKEmbedAudioEngine()
    
    public weak var delegate: WKEmbedAudioEngineDelegate?
    
    public var diagnostics = EmbedPlayerDiagnostics()
    
    public private(set) var isReady: Bool = false
    public private(set) var isPlaying: Bool = false
    public private(set) var isLoading: Bool = false
    public private(set) var currentVideoId: String?
    
    public var currentTime: Double {
        diagnostics.playerCurrentTime
    }
    
    private var webView: WKWebView?
    private var progressTimer: Task<Void, Never>?
    private var appStateObservers: [any NSObjectProtocol] = []
    
    override public init() {
        super.init()
        setupAudioSession()
        setupWebView()
        setupAppStateObservers()
    }
    
    // MARK: - Audio Session Configuration
    public func setupAudioSession() {
        #if canImport(AVFAudio)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
            try session.setActive(true)
            diagnostics.audioSessionCategory = session.category.rawValue
            diagnostics.audioSessionActive = true
            print("[WKEmbedAudioEngine] AVAudioSession configured: .playback, active=true")
        } catch {
            print("[WKEmbedAudioEngine] AVAudioSession error:", error)
            diagnostics.audioSessionActive = false
        }
        #endif
    }
    
    // MARK: - WebView Setup
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = false
        
        // Add script message handler
        config.userContentController.add(self, name: "handler")
        
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 240), configuration: config)
        wv.navigationDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = .clear
        
        // Set Desktop Safari User-Agent matching Demus binary evidence
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.5 Safari/605.1.15"
        
        self.webView = wv
        loadPlayerHTML()
    }
    
    public func getWebView() -> WKWebView? {
        return self.webView
    }
    
    // MARK: - Load Demus Player Template
    private func loadPlayerHTML() {
        guard let wv = webView else { return }
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
            #player { width: 100%; height: 100%; top: 0; left: 0; position: absolute; border: 0; }
          </style>
        </head>
        <body>
          <iframe id="player" style="width:100%;height:100%;top:0;left:0;position:absolute" frameborder="0" src="https://www.youtube-nocookie.com/embed?enablejsapi=1&autoplay=1&controls=0&fs=0&rel=0&playsinline=1"></iframe>
          <script>
            let audioSource = "data:audio/mp3;base64,./+MYxAAAAANIAAAAAExBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxDsAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxHYAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxLEAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV/+MYxMQAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV";
            let audio = new Audio(audioSource);
            var alreadyPlayed = false;

            var tag = document.createElement("script");
            tag.src = "https://www.youtube.com/iframe_api";
            var firstScriptTag = document.getElementsByTagName("script")[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

            var player;
            var playerWindow;

            function onYouTubeIframeAPIReady() {
                player = new YT.Player("player", {
                    events: {
                        "onReady": onPlayerReady,
                        "onStateChange": onPlayerStateChange,
                        "onError": onPlayerError
                    }
                });
            }

            function send(message) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.handler) {
                    window.webkit.messageHandlers.handler.postMessage(message);
                }
            }

            function video() {
                try {
                    return playerWindow ? playerWindow.document.querySelector("video") : null;
                } catch(e) { return null; }
            }

            function onPlayerReady(event) {
                try {
                    playerWindow = document.getElementById("player").contentWindow;
                    setupMediaSession();
                    setupMediaSessionMetadata();
                    setupEventListeners();
                } catch(e) {}
                send({type: "ready"});
            }

            function onPlayerStateChange(event) {
                send({type: "state", code: event.data});
            }

            function onPlayerError(event) {
                send({type: "error", code: event.data});
                if (event.data == 101 || event.data == 150) {
                    send({type: "restricted"});
                }
            }

            function setupMediaSession() {
                let targets = [window];
                if (playerWindow) { targets.push(playerWindow); }
                for (let wnd of targets) {
                    try {
                        wnd.navigator.mediaSession.setActionHandler("play", () => { send({type: "play"}); });
                        wnd.navigator.mediaSession.setActionHandler("pause", () => { send({type: "pause"}); });
                        wnd.navigator.mediaSession.setActionHandler("seekbackward", null);
                        wnd.navigator.mediaSession.setActionHandler("seekforward", null);
                        wnd.navigator.mediaSession.setActionHandler("previoustrack", () => { send({type: "prev"}); });
                        wnd.navigator.mediaSession.setActionHandler("nexttrack", () => { send({type: "next"}); });
                        wnd.navigator.mediaSession.setActionHandler("seekto", (details) => {
                            send({type: "seek", time: details.seekTime});
                        });
                    } catch(e) {}
                }
            }

            function setupMediaSessionMetadata() {
                let targets = [window];
                if (playerWindow) { targets.push(playerWindow); }
                for (let wnd of targets) {
                    try {
                        const ms = wnd.navigator.mediaSession;
                        const proto = Object.getPrototypeOf(ms);
                        const original = Object.getOwnPropertyDescriptor(proto, "metadata");
                        let _metadata = null;
                        Object.defineProperty(ms, "metadata", {
                            get() { return _metadata; },
                            set(value) {
                                if (value && value.artwork && value.artwork[0]?.sizes === "1500x1500") {
                                    _metadata = value;
                                    if (original && original.set) { original.set.call(ms, value); }
                                }
                            },
                            enumerable: true,
                            configurable: true
                        });
                    } catch(e) {}
                }
            }

            function setupEventListeners() {
                let targets = [window];
                if (playerWindow) { targets.push(playerWindow); }
                for (let wnd of targets) {
                    try {
                        Object.defineProperty(wnd.document, "visibilityState", { value: "visible", configurable: true });
                        Object.defineProperty(wnd.document, "hidden", { value: false, configurable: true });
                    } catch(e) {}
                }
                if (playerWindow) {
                    try {
                        playerWindow.addEventListener("visibilitychange", (e) => {
                            e.stopPropagation();
                            send({type: "visibility"});
                        }, true);
                    } catch(e) {}
                }
            }
          </script>
        </body>
        </html>
        """
        
        print("[WKEmbedAudioEngine] Loading Demus embed player HTML...")
        wv.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com")!)
    }
    
    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.diagnostics.webViewLoaded = true
        print("[WKEmbedAudioEngine] WebView didFinish navigation")
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.diagnostics.playerError = error.localizedDescription
        print("[WKEmbedAudioEngine] WebView navigation failed:", error.localizedDescription)
    }
    
    // MARK: - WKScriptMessageHandler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        
        switch type {
        case "ready":
            self.isReady = true
            self.diagnostics.playerReady = true
            self.diagnostics.playerError = "None"
            print("[WKEmbedAudioEngine] YouTube Embed Player is READY")
            delegate?.embedAudioEngineDidReady()
            
        case "state":
            if let code = body["code"] as? Int {
                handleStateChange(code: code)
            }
            
        case "error":
            let code = body["code"] as? Int ?? -1
            self.diagnostics.playerError = "YouTube Error Code \(code)"
            print("[WKEmbedAudioEngine] YouTube Error received: \(code)")
            delegate?.embedAudioEngineDidFail(error: "YouTube Error Code \(code)")
            
        case "restricted":
            self.diagnostics.playerError = "Video restricted by YouTube (code 101/150)"
            print("[WKEmbedAudioEngine] Video restricted by content owner")
            delegate?.embedAudioEngineDidFail(error: "Video restricted for embed")
            
        case "play":
            play()
            
        case "pause":
            pause()
            
        case "next":
            delegate?.embedAudioEngineDidRequestNext()
            
        case "prev":
            delegate?.embedAudioEngineDidRequestPrev()
            
        case "seek":
            if let time = body["time"] as? Double {
                seek(to: time)
            }
            
        case "visibility":
            break
            
        default:
            break
        }
    }
    
    private func handleStateChange(code: Int) {
        switch code {
        case -1: // Unstarted
            self.diagnostics.playerState = "unstarted"
            
        case 0: // Ended
            self.diagnostics.playerState = "ended"
            self.isPlaying = false
            self.isLoading = false
            stopProgressTimer()
            print("[WKEmbedAudioEngine] Track finished playback")
            delegate?.embedAudioEngineDidEnd()
            
        case 1: // Playing
            self.diagnostics.playerState = "playing"
            self.isPlaying = true
            self.isLoading = false
            startProgressTimer()
            delegate?.embedAudioEngineDidChangeState(isPlaying: true, isLoading: false)
            
        case 2: // Paused
            self.diagnostics.playerState = "paused"
            self.isPlaying = false
            self.isLoading = false
            stopProgressTimer()
            delegate?.embedAudioEngineDidChangeState(isPlaying: false, isLoading: false)
            
        case 3: // Buffering
            self.diagnostics.playerState = "buffering"
            self.isLoading = true
            delegate?.embedAudioEngineDidChangeState(isPlaying: isPlaying, isLoading: true)
            
        case 5: // Video cued
            self.diagnostics.playerState = "cued"
            self.isLoading = false
            
        default:
            break
        }
    }
    
    // MARK: - Playback Controls
    public func loadAndPlay(
        videoId: String,
        title: String,
        artist: String,
        album: String,
        artworkUrl: String,
        duration: Double
    ) {
        self.currentVideoId = videoId
        self.isLoading = true
        self.diagnostics.playerError = "None"
        setupAudioSession()
        
        let escTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escArtist = artist.replacingOccurrences(of: "\"", with: "\\\"")
        let escAlbum = album.replacingOccurrences(of: "\"", with: "\\\"")
        let escArtwork = artworkUrl.replacingOccurrences(of: "\"", with: "\\\"")
        
        let js = """
        (() => {
            try {
                let targets = [window];
                if (playerWindow) { targets.push(playerWindow); }
                for (let wnd of targets) {
                    try {
                        wnd.navigator.audioSession.type = "playback";
                        wnd.navigator.mediaSession.metadata = new MediaMetadata({
                            title: "\(escTitle)",
                            artist: "\(escArtist)",
                            album: "\(escAlbum)",
                            artwork: [{ src: "\(escArtwork)", sizes: "1500x1500", type: "image/jpeg" }]
                        });
                        wnd.navigator.mediaSession.setPositionState({ duration: \(duration > 0 ? duration : 180) });
                    } catch(e) {}
                }
                if (player && typeof player.loadVideoById === "function") {
                    try {
                        if (typeof player.unMute === "function") { player.unMute(); }
                        if (typeof player.setVolume === "function") { player.setVolume(100); }
                    } catch(e) {}
                    player.loadVideoById("\(videoId)");
                    alreadyPlayed = true;
                    try { if (audio) { audio.play(); } } catch(e) {}
                }
            } catch(e) {
                console.log(e);
            }
        })()
        """
        
        print("[WKEmbedAudioEngine] loadAndPlay: \(title) (\(videoId))")
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    public func play() {
        setupAudioSession()
        
        let js = """
        (() => {
            try {
                let targets = [window];
                if (playerWindow) { targets.push(playerWindow); }
                for (let wnd of targets) {
                    try {
                        wnd.navigator.audioSession.type = "playback";
                    } catch(e) {}
                }
                if (typeof audio !== 'undefined' && audio) {
                    audio.play().catch(() => {});
                }
                if (playerWindow) {
                    let v = playerWindow.document.querySelector("video");
                    if (v && v.paused) {
                        v.play().catch(() => {});
                    }
                }
            } catch(e) {}
            if (player && typeof player.playVideo === 'function') {
                player.playVideo();
            }
        })()
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
        
        // Resilience Watchdog: If playback doesn't start within 1.2s (e.g. paused for 1-2 mins and connection went idle)
        let savedTime = self.currentTime
        guard let vId = self.currentVideoId, !vId.isEmpty else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s
            guard let self = self, self.isPlaying, self.diagnostics.playerState != "playing" else { return }
            print("[WKEmbedAudioEngine] Stalled stream recovery triggered at \(savedTime)s")
            
            let recoveryJS = """
            (() => {
                try {
                    if (player && typeof player.getPlayerState === 'function') {
                        let st = player.getPlayerState();
                        if (st !== 1) {
                            if (typeof player.seekTo === 'function') {
                                player.seekTo(\(savedTime), true);
                            }
                            if (typeof player.playVideo === 'function') {
                                player.playVideo();
                            }
                        }
                    }
                } catch(e) {}
            })()
            """
            self.webView?.evaluateJavaScript(recoveryJS, completionHandler: nil)
            
            // Stage 2: If stream socket dropped during idle pause, re-load video at exact saved time
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            guard self.isPlaying, self.diagnostics.playerState != "playing" else { return }
            print("[WKEmbedAudioEngine] Re-anchoring stream via loadVideoById at \(savedTime)s")
            
            let reloadJS = """
            (() => {
                try {
                    if (player && typeof player.loadVideoById === 'function') {
                        player.loadVideoById({
                            videoId: "\(vId)",
                            startSeconds: \(savedTime)
                        });
                    }
                } catch(e) {}
            })()
            """
            self.webView?.evaluateJavaScript(reloadJS, completionHandler: nil)
        }
    }
    
    public func pause() {
        let js = """
        (() => {
            try {
                if (typeof audio !== 'undefined' && audio) {
                    audio.pause();
                }
            } catch(e) {}
            if (player && typeof player.pauseVideo === 'function') {
                player.pauseVideo();
            }
        })()
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    public func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func seek(to seconds: TimeInterval) {
        let js = "if (player && typeof player.seekTo === 'function') { player.seekTo(\(seconds), true); }"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    public func setVolume(_ volume: Double) {
        let vol = Int(max(0, min(100, volume * 100)))
        let js = "if (player && typeof player.setVolume === 'function') { player.setVolume(\(vol)); }"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    // MARK: - Progress Polling Timer
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                guard let self = self, self.isPlaying else { break }
                
                let queryJS = """
                (() => {
                    try {
                        if (player && typeof player.getCurrentTime === 'function') {
                            let cur = player.getCurrentTime() || 0;
                            let dur = player.getDuration() || 0;
                            let rate = player.getPlaybackRate() || 1;
                            try {
                                if (playerWindow && playerWindow.navigator.mediaSession) {
                                    playerWindow.navigator.mediaSession.setPositionState({
                                        duration: dur,
                                        playbackRate: rate,
                                        position: cur
                                    });
                                }
                            } catch(e) {}
                            return { time: cur, duration: dur, rate: rate };
                        }
                    } catch(e) {}
                    return null;
                })()
                """
                
                do {
                    let result = try await self.webView?.evaluateJavaScript(queryJS)
                    if let dict = result as? [String: Any],
                       let t = dict["time"] as? Double {
                        let dur = dict["duration"] as? Double ?? 0
                        let rate = Float(dict["rate"] as? Double ?? 1.0)
                        
                        self.diagnostics.playerCurrentTime = t
                        if dur > 0 { self.diagnostics.playerDuration = dur }
                        self.diagnostics.playerRate = rate
                        
                        self.delegate?.embedAudioEngineDidUpdateTime(currentTime: t, duration: dur)
                    }
                } catch {
                    // Ignore transient evaluation errors
                }
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.cancel()
        progressTimer = nil
    }
    
    // MARK: - App State Observers
    private func setupAppStateObservers() {
        #if canImport(UIKit)
        let activeObs = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.diagnostics.appState = "active (foreground)"
                self.diagnostics.firstStateAfterForeground = self.diagnostics.playerState
                print("[WKEmbedAudioEngine] App became active. Current playerState: \(self.diagnostics.playerState)")
            }
        }
        
        let bgObs = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.diagnostics.appState = "background"
                self.diagnostics.lastStateBeforeBackground = self.diagnostics.playerState
                print("[WKEmbedAudioEngine] App entered background. PlayerState was: \(self.diagnostics.playerState)")
            }
        }
        
        appStateObservers = [activeObs, bgObs]
        #endif
    }
}

// MARK: - WKEmbedAudioEngineView (Representable)
/// Real, attached media view layer placed behind the SwiftUI interface.
/// Renders YouTube's embed player without being destroyed or hidden with display:none.
public struct WKEmbedAudioEngineView: UIViewRepresentable {
    public init() {}
    
    public func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false
        if let wv = WKEmbedAudioEngine.shared.getWebView() {
            wv.frame = container.bounds
            wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(wv)
        }
        return container
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
}
