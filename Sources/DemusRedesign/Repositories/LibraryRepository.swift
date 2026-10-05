import Foundation

// MARK: - LibraryRepository
/// Manages user's saved Library tracks, favorites, custom playlists, and playback history.
public final class LibraryRepository: @unchecked Sendable {
    public static let shared = LibraryRepository()
    
    private let fileManager = FileManager.default
    private let storageURL: URL
    
    private struct StorageData: Codable {
        var librarySongs: [Song]
        var playlists: [Playlist]
        var history: [Song]
    }
    
    public var librarySongs: [Song] = []
    public var playlists: [Playlist] = []
    public var history: [Song] = []
    
    public init() {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docDir = urls.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storageURL = docDir.appendingPathComponent("demus_library.json")
        load()
    }
    
    public func addSong(_ song: Song) {
        if !librarySongs.contains(where: { $0.id == song.id }) {
            librarySongs.insert(song, at: 0)
            save()
        }
    }
    
    public func removeSong(id: String) {
        librarySongs.removeAll(where: { $0.id == id })
        save()
    }
    
    public func toggleFavorite(for song: Song) {
        if let index = librarySongs.firstIndex(where: { $0.id == song.id }) {
            librarySongs[index].isFavorite.toggle()
        } else {
            var newSong = song
            newSong.isFavorite = true
            librarySongs.insert(newSong, at: 0)
        }
        save()
    }
    
    public func addPlaylist(_ playlist: Playlist) {
        playlists.insert(playlist, at: 0)
        save()
    }
    
    public func addHistory(_ song: Song) {
        history.removeAll(where: { $0.id == song.id })
        history.insert(song, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        save()
    }
    
    private func save() {
        let data = StorageData(librarySongs: librarySongs, playlists: playlists, history: history)
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: storageURL)
        }
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode(StorageData.self, from: data) else {
            return
        }
        self.librarySongs = decoded.librarySongs
        self.playlists = decoded.playlists
        self.history = decoded.history
    }
}
