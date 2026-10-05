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
    private var silentAudioPlayer: AVAudioPlayer?
    
    override public init() {
        super.init()
        setupAudioSession()
        // Controlled isolation: setupSilentAudioKeeper()
        setupWebView()
        // Controlled isolation: setupBackgroundObservers()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("[WKAudioEngine] AVAudioSession setup error:", error)
        }
    }
    
    // MARK: - Silent Audio Keeper (Demus Technique)
    /// Runs a 0-volume native audio loop so iOS background power manager never suspends WebKit.
    private func setupSilentAudioKeeper() {
        // Standard 44-byte WAV header + silent PCM buffer
        var header = [UInt8](repeating: 0, count: 44)
        header[0] = 0x52; header[1] = 0x49; header[2] = 0x46; header[3] = 0x46 // RIFF
        let chunkSize: UInt32 = 4036
        header[4] = UInt8(chunkSize & 0xff); header[5] = UInt8((chunkSize >> 8) & 0xff)
        header[6] = UInt8((chunkSize >> 16) & 0xff); header[7] = UInt8((chunkSize >> 24) & 0xff)
        header[8] = 0x57; header[9] = 0x41; header[10] = 0x56; header[11] = 0x45 // WAVE
        header[12] = 0x66; header[13] = 0x6d; header[14] = 0x74; header[15] = 0x20 // fmt
        header[16] = 16; header[20] = 1; header[22] = 1 // PCM, 1 channel
        let sampleRate: UInt32 = 8000
        header[24] = UInt8(sampleRate & 0xff); header[25] = UInt8((sampleRate >> 8) & 0xff)
        let byteRate: UInt32 = 16000
        header[28] = UInt8(byteRate & 0xff); header[29] = UInt8((byteRate >> 8) & 0xff)
        header[32] = 2; header[34] = 16 // 16-bit
        header[36] = 0x64; header[37] = 0x61; header[38] = 0x74; header[39] = 0x61 // data
        let dataSize: UInt32 = 4000
        header[40] = UInt8(dataSize & 0xff); header[41] = UInt8((dataSize >> 8) & 0xff)
        
        var fullData = Data(header)
        fullData.append(Data(repeating: 0, count: Int(dataSize)))
        
        do {
            let player = try AVAudioPlayer(data: fullData)
            player.numberOfLoops = -1
            player.volume = 0.0001
            player.prepareToPlay()
            player.play()
            self.silentAudioPlayer = player
        } catch {
            print("[WKAudioEngine] SilentAudioKeeper setup error:", error)
        }
    }
    
    // MARK: - Background Notification Observers
    private func setupBackgroundObservers() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {}
            Task { @MainActor [weak self] in
                if self?.silentAudioPlayer?.isPlaying != true {
                    self?.silentAudioPlayer?.play()
                }
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
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "audioBridge")
        config.userContentController = contentController
        
        // 1x1 hidden frame
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.isHidden = true
        
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
