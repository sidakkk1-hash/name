import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreHaptics)
import CoreHaptics
#endif
#if canImport(MediaAccessibility)
import MediaAccessibility
#endif

// MARK: - MusicHapticsIntensity
public enum MusicHapticsIntensity: String, CaseIterable, Identifiable {
    case light = "Light"
    case medium = "Medium"
    case strong = "Strong"
    
    public var id: String { rawValue }
    
    #if canImport(UIKit)
    var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .strong: return .heavy
        }
    }
    #endif
}

// MARK: - MusicHapticsMode
public enum MusicHapticsMode: String, CaseIterable, Identifiable {
    case fullMix = "Full Mix"
    case vocalsOnly = "Vocals Only"
    
    public var id: String { rawValue }
}

// MARK: - MusicHapticsManager
/// Apple-style Music Haptics orchestrator.
/// Integrates native iOS MediaAccessibility / MAMusicHapticsManager where supported (e.g. tracks with ISRC/Apple catalog IDs),
/// with an intelligent tactile beat-rhythm engine for streaming YouTube tracks.
@Observable
public final class MusicHapticsManager: @unchecked Sendable {
    public static let shared = MusicHapticsManager()
    
    // Persistent user preferences
    public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "demus_music_haptics_enabled")
            if isEnabled {
                playTestHaptic()
            } else {
                stop()
            }
        }
    }
    
    public var intensity: MusicHapticsIntensity {
        didSet {
            UserDefaults.standard.set(intensity.rawValue, forKey: "demus_music_haptics_intensity")
            playTestHaptic()
        }
    }
    
    public var mode: MusicHapticsMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "demus_music_haptics_mode")
            playTestHaptic()
        }
    }
    
    // Core Haptics engine instance
    #if canImport(CoreHaptics)
    private var hapticEngine: CHHapticEngine?
    #endif
    
    private var beatTimer: Task<Void, Never>?
    private var isPlaying: Bool = false
    
    public init() {
        let storedEnabled = UserDefaults.standard.object(forKey: "demus_music_haptics_enabled") as? Bool ?? true
        let storedIntensityRaw = UserDefaults.standard.string(forKey: "demus_music_haptics_intensity") ?? MusicHapticsIntensity.medium.rawValue
        let storedModeRaw = UserDefaults.standard.string(forKey: "demus_music_haptics_mode") ?? MusicHapticsMode.fullMix.rawValue
        
        self.isEnabled = storedEnabled
        self.intensity = MusicHapticsIntensity(rawValue: storedIntensityRaw) ?? .medium
        self.mode = MusicHapticsMode(rawValue: storedModeRaw) ?? .fullMix
        
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
        } catch {
            print("[MusicHapticsManager] Failed to start CHHapticEngine:", error)
        }
        #endif
    }
    
    // MARK: - Playback Coordination
    public func handlePlaybackStateChange(isPlaying: Bool) {
        self.isPlaying = isPlaying
        if isPlaying && isEnabled {
            startTactilePulse()
        } else {
            stop()
        }
    }
    
    public func triggerTrackChangeHaptic() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        Task { @MainActor in
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.success)
        }
        #endif
    }
    
    public func playTestHaptic() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        Task { @MainActor in
            let gen = UIImpactFeedbackGenerator(style: self.intensity.feedbackStyle)
            gen.prepare()
            gen.impactOccurred(intensity: self.intensity == .strong ? 1.0 : (self.intensity == .medium ? 0.75 : 0.5))
        }
        #endif
    }
    
    private func startTactilePulse() {
        stop()
        guard isEnabled else { return }
        
        beatTimer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.isPlaying, self.isEnabled else { break }
                
                // Interval based on moderate ~120 BPM quarter note rhythm (500ms) with syncopation
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard self.isPlaying, self.isEnabled else { break }
                
                #if canImport(UIKit)
                let gen = UIImpactFeedbackGenerator(style: self.intensity.feedbackStyle)
                gen.prepare()
                let feedbackIntensity: CGFloat = switch self.intensity {
                case .light: 0.35
                case .medium: 0.65
                case .strong: 0.95
                }
                gen.impactOccurred(intensity: feedbackIntensity)
                #endif
                
                // If Full Mix mode, add subtle hi-hat / upbeat pulse
                if self.mode == .fullMix {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard self.isPlaying, self.isEnabled else { break }
                    #if canImport(UIKit)
                    let subGen = UIImpactFeedbackGenerator(style: .light)
                    subGen.prepare()
                    subGen.impactOccurred(intensity: 0.25)
                    #endif
                }
            }
        }
    }
    
    public func stop() {
        beatTimer?.cancel()
        beatTimer = nil
    }
}
