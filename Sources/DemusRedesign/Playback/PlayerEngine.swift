import Foundation
import Combine
import SwiftUI

// MARK: - PlayerEngine Protocol & State
@Observable
public final class PlayerEngine: @unchecked Sendable {
    public static let shared = PlayerEngine()
    
    // Playback state
    public var currentSong: Song?
    public var isPlaying: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 180
    public var queue: [Song] = []
    public var history: [Song] = []
    public var isShuffle: Bool = false
    public var isRepeat: Bool = false
    
    private var timer: Timer?
    
    public init() {
        setupSampleContent()
    }
    
    public func setupSampleContent() {
        self.queue = MockData.sampleSongs
        if let first = queue.first {
            self.currentSong = first
            self.duration = first.duration
        }
    }
    
    public func play(song: Song) {
        // If already current song, just resume if paused
        if currentSong?.id == song.id {
            if !isPlaying {
                togglePlay()
            }
            return
        }
        self.currentSong = song
        self.duration = song.duration
        self.currentTime = 0
        self.isPlaying = true
        startTimer()
    }
    
    public func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    public func next() {
        guard let current = currentSong, let idx = queue.firstIndex(where: { $0.id == current.id }) else {
            if let first = queue.first { play(song: first) }
            return
        }
        history.append(current)
        if isShuffle {
            let remaining = queue.filter { $0.id != current.id }
            if let randomSong = remaining.randomElement() {
                play(song: randomSong)
                return
            }
        }
        if idx + 1 < queue.count {
            play(song: queue[idx + 1])
        } else if isRepeat || queue.count > 0 {
            play(song: queue[0])
        } else {
            isPlaying = false
            stopTimer()
        }
    }
    
    public func prev() {
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        guard let current = currentSong, let idx = queue.firstIndex(where: { $0.id == current.id }) else { return }
        if idx > 0 {
            play(song: queue[idx - 1])
        } else if let last = queue.last {
            play(song: last)
        }
    }
    
    public func seek(to time: TimeInterval) {
        self.currentTime = max(0, min(time, duration))
    }
    
    public func toggleFavorite(for songId: String) {
        if let idx = queue.firstIndex(where: { $0.id == songId }) {
            queue[idx].isFavorite.toggle()
            if currentSong?.id == songId {
                currentSong?.isFavorite = queue[idx].isFavorite
            }
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            if self.currentTime < self.duration {
                self.currentTime += 1
            } else {
                self.next()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
