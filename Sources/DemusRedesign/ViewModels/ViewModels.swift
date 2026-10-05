import Foundation
import SwiftUI

// MARK: - App Tab Enum
public enum AppTab: Int, CaseIterable, Identifiable, Sendable {
    case explore = 0
    case search = 1
    case songs = 2
    case playlists = 3
    case settings = 4
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .explore: return "Listen Now"
        case .search: return "Search"
        case .songs: return "Library"
        case .playlists: return "Playlists"
        case .settings: return "Settings"
        }
    }
    
    public var iconName: String {
        switch self {
        case .explore: return "play.circle.fill"
        case .search: return "magnifyingglass"
        case .songs: return "square.stack.fill"
        case .playlists: return "music.note.list"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - MainTVM (Matches Demus.MainTVM class)
@Observable
public final class MainTVM: @unchecked Sendable {
    public static let shared = MainTVM()
    
    public var selectedTab: AppTab = .explore
    public var isNowPlayingPresented: Bool = false
    public var isQueuePresented: Bool = false
    public var isLyricsPresented: Bool = false
    public var options: AppOptions = AppOptions()
    
    public init() {}
}

// MARK: - SearchVM (Matches Demus Demus8SearchVM)
@Observable
public final class SearchVM: @unchecked Sendable {
    public var query: String = ""
    public var searchResults: [Song] = []
    public var matchedAlbums: [Album] = []
    public var matchedArtists: [Artist] = []
    public var searchHistory: [String] = ["The Weeknd", "Daft Punk", "Billie Eilish", "Taylor Swift"]
    public var suggestions: [String] = []
    public var isSearching: Bool = false
    public var categories: [MusicCategory] = SearchCategories.all
    
    private var searchTask: Task<Void, Never>?
    
    public init() {}
    
    // MARK: - Live Search Execution
    public func performSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !q.isEmpty else {
            searchResults = []
            matchedAlbums = []
            matchedArtists = []
            suggestions = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        searchTask = Task { @MainActor in
            // Small debounce
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            
            let response = await SearchService.shared.searchAll(query: q)
            guard !Task.isCancelled else { return }
            
            self.searchResults = response.songs
            self.matchedAlbums = response.albums
            self.matchedArtists = response.artists
            self.isSearching = false
            
            // Add to search history if not duplicate
            if !self.searchHistory.contains(q) && response.songs.count > 0 {
                self.searchHistory.insert(q, at: 0)
                if self.searchHistory.count > 10 {
                    self.searchHistory.removeLast()
                }
            }
        }
    }
    
    // MARK: - Live Suggestion Typing
    public func fetchSuggestions() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            suggestions = []
            return
        }
        
        Task { @MainActor in
            let list = await SearchService.shared.fetchSuggestions(for: q)
            if !Task.isCancelled {
                self.suggestions = list
            }
        }
    }
}

// MARK: - SongVM (Matches Demus.SongVM)
@Observable
public final class SongVM: @unchecked Sendable {
    public var volume: Double = 0.8
    public var isLiked: Bool = false
    
    public init() {}
}
