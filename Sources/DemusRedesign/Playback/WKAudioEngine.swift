import Foundation
import WebKit
import Combine
import CoreGraphics
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

// MARK: - WKAudioEngine
/// WebKit-powered background YouTube audio engine matching Demus's EmbedPlayer / WebPlayer architecture.
/// Bypasses googlevideo 403 Forbidden bot-detection and ensures continuous background playback.
@MainActor
public final class WKAudioEngine: NSObject, WKScriptMessageHandler, @unchecked Sendable {
    public static let shared = WKAudioEngine()
    
    public weak var delegate: WKAudioEngineDelegate?
    
    private var webView: WKWebView?
    private var isPlayerReady: Bool = false
    private var currentVideoId: String?
    
    override public init() {
        super.init()
        setupAudioSession()
        setupWebView()
        setupBackgroundObservers()
    }
    
    // MARK: - Audio Session Setup
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
        } catch {
            print("[WKAudioEngine] AVAudioSession setup error:", error)
        }
        #endif
    }
    
    // MARK: - Background Notification Observers
    private func setupBackgroundObservers() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            #if canImport(AVFAudio)
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {}
            #endif
            Task { @MainActor [weak self] in
                self?.webView?.evaluateJavaScript("if (player && player.playVideo) { player.playVideo(); }")
            }
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
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "audioBridge")
        config.userContentController = contentController
        
        // 1x1 frame
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.alpha = 0.01
        
        self.webView = wv
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
        // Override document visibility so YouTube iframe never pauses in background
        try {
            Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
            Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
            document.addEventListener('visibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);
        } catch(e) {}

        var tag = document.createElement('script');
        tag.src = "https://www.youtube.com/iframe_api";
        var firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

        var player;
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
            window.webkit.messageHandlers.audioBridge.postMessage({event: 'ready'});
            if (pendingId) {
                player.loadVideoById(pendingId);
                pendingId = null;
            }
        }

        function onPlayerStateChange(event) {
            var cur = (player && player.getCurrentTime) ? player.getCurrentTime() : 0;
            var dur = (player && player.getDuration) ? player.getDuration() : 0;
            window.webkit.messageHandlers.audioBridge.postMessage({
                event: 'stateChange',
                state: event.data,
                currentTime: cur,
                duration: dur
            });
        }

        function onPlayerError(event) {
            window.webkit.messageHandlers.audioBridge.postMessage({
                event: 'error',
                code: event.data
            });
        }

        function loadVideo(id) {
            if (isReady && player && player.loadVideoById) {
                player.loadVideoById(id);
            } else {
                pendingId = id;
            }
        }

        function playVideo() {
            if (player && player.playVideo) { player.playVideo(); }
        }

        function pauseVideo() {
            if (player && player.pauseVideo) { player.pauseVideo(); }
        }

        function seekTo(sec) {
            if (player && player.seekTo) { player.seekTo(sec, true); }
        }

        function setVolume(val) {
            if (player && player.setVolume) { player.setVolume(val); }
        }

        setInterval(function() {
            if (player && isReady && player.getPlayerState && player.getPlayerState() === 1) {
                var cur = player.getCurrentTime() || 0;
                var dur = player.getDuration() || 0;
                window.webkit.messageHandlers.audioBridge.postMessage({
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
    public func loadAndPlay(videoId: String) {
        self.currentVideoId = videoId
        let escaped = videoId.replacingOccurrences(of: "'", with: "\\'")
        let js = "loadVideo('\(escaped)');"
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
    
    // MARK: - WKScriptMessageHandler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let event = dict["event"] as? String else { return }
        
        switch event {
        case "ready":
            self.isPlayerReady = true
            delegate?.audioEngineDidReady()
            
        case "stateChange":
            if let state = dict["state"] as? Int {
                // 1 = PLAYING, 2 = PAUSED, 3 = BUFFERING, 0 = ENDED
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
            
        case "error":
            let code = dict["code"] as? Int ?? -1
            delegate?.audioEngineDidFail(error: "Playback error code: \(code)")
            
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
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        container.isHidden = true
        if let wv = WKAudioEngine.shared.getWebView() {
            container.addSubview(wv)
        }
        return container
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
