import Foundation
import SwiftUI

// MARK: - App Tab Enum
public enum AppTab: Int, CaseIterable, Identifiable, Sendable {
    case explore = 0
    case radio = 1
    case songs = 2
    case search = 3
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .explore: return "Home"
        case .radio: return "Radio"
        case .songs: return "Library"
        case .search: return "Search"
        }
    }
    
    public var iconName: String {
        switch self {
        case .explore: return "house.fill"
        case .radio: return "dot.radiowaves.left.and.right"
        case .songs: return "square.stack.fill"
        case .search: return "magnifyingglass"
        }
    }
    
    // Aliases for compatibility
    public static var playlists: AppTab { .songs }
    public static var settings: AppTab { .songs }
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

// MARK: - SearchSectionFilter
public enum SearchSectionFilter: String, CaseIterable, Identifiable, Sendable {
    case topResults = "Top Results"
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"
    
    public var id: String { rawValue }
}

// MARK: - SearchVM (Matches Demus Demus8SearchVM)
@Observable
public final class SearchVM: @unchecked Sendable {
    public static let shared = SearchVM()
    
    public var query: String = ""
    public var selectedSection: SearchSectionFilter = .topResults
    public var topResults: [TopResultItem] = []
    public var searchResults: [Song] = []
    public var matchedAlbums: [Album] = []
    public var matchedArtists: [Artist] = []
    public var matchedPlaylists: [Playlist] = []
    public var searchHistory: [String] {
        LibraryRepository.shared.searchHistory
    }
    public var suggestions: [String] = []
    public var isSearching: Bool = false
    public var categories: [MusicCategory] = SearchCategories.all
    
    private var searchTask: Task<Void, Never>?
    private var suggestionTask: Task<Void, Never>?
    
    public init() {}
    
    // MARK: - Live Search Execution
    public func performSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !q.isEmpty else {
            clearResults()
            return
        }
        
        isSearching = true
        
        searchTask = Task { @MainActor in
            // Fast debounce
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            
            let response = await SearchService.shared.searchAll(query: q)
            guard !Task.isCancelled else { return }
            
            self.topResults = response.topResults
            self.searchResults = response.songs
            self.matchedAlbums = response.albums
            self.matchedArtists = response.artists
            self.matchedPlaylists = response.playlists
            self.isSearching = false
            
            // Persist to real search history if songs returned
            if !response.songs.isEmpty {
                LibraryRepository.shared.addSearchQuery(q)
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
    
    public func clearResults() {
        searchResults = []
        matchedAlbums = []
        matchedArtists = []
        matchedPlaylists = []
        topResults = []
        suggestions = []
        isSearching = false
    }
}

// MARK: - SongVM (Matches Demus.SongVM)
@Observable
public final class SongVM: @unchecked Sendable {
    public var volume: Double = 0.8
    public var isLiked: Bool = false
    
    public init() {}
}
