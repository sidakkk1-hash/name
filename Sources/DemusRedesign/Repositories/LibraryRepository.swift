import Foundation

// MARK: - LibraryRepository
/// Manages user's saved Library tracks, favorites, custom playlists, listening history, and search history.
public final class LibraryRepository: @unchecked Sendable {
    public static let shared = LibraryRepository()
    
    private let fileManager = FileManager.default
    private let storageURL: URL
    
    private struct StorageData: Codable {
        var librarySongs: [Song]
        var playlists: [Playlist]
        var history: [Song]
        var searchHistory: [String]?
    }
    
    public var librarySongs: [Song] = []
    public var playlists: [Playlist] = []
    public var history: [Song] = []
    public var searchHistory: [String] = []
    
    public init() {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docDir = urls.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storageURL = docDir.appendingPathComponent("demus_library.json")
        load()
    }
    
    // MARK: - Library Songs
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
    
    public func isInLibrary(id: String) -> Bool {
        librarySongs.contains(where: { $0.id == id })
    }
    
    // MARK: - Favorites
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
    
    public func isFavorite(id: String) -> Bool {
        librarySongs.contains(where: { $0.id == id && $0.isFavorite })
    }
    
    // MARK: - Playlists
    public func addPlaylist(_ playlist: Playlist) {
        playlists.insert(playlist, at: 0)
        save()
    }
    
    public func deletePlaylist(id: String) {
        playlists.removeAll(where: { $0.id == id })
        save()
    }
    
    public func addSong(_ song: Song, to playlistId: String) {
        if let idx = playlists.firstIndex(where: { $0.id == playlistId }) {
            if !playlists[idx].songs.contains(where: { $0.id == song.id }) {
                playlists[idx].songs.append(song)
                save()
            }
        }
    }
    
    public func removeSong(songId: String, from playlistId: String) {
        if let idx = playlists.firstIndex(where: { $0.id == playlistId }) {
            playlists[idx].songs.removeAll(where: { $0.id == songId })
            save()
        }
    }
    
    // MARK: - Listening History
    public func addHistory(_ song: Song) {
        history.removeAll(where: { $0.id == song.id })
        history.insert(song, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        save()
    }
    
    // MARK: - Search History
    public func addSearchQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchHistory.removeAll(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        searchHistory.insert(trimmed, at: 0)
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        save()
    }
    
    public func removeSearchQuery(_ query: String) {
        searchHistory.removeAll(where: { $0 == query })
        save()
    }
    
    public func clearSearchHistory() {
        searchHistory.removeAll()
        save()
    }
    
    // MARK: - Persistence
    private func save() {
        let data = StorageData(
            librarySongs: librarySongs,
            playlists: playlists,
            history: history,
            searchHistory: searchHistory
        )
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
        self.searchHistory = decoded.searchHistory ?? []
    }
}
