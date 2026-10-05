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

// MARK: - SearchVM (Matches Demus.SearchVM)
@Observable
public final class SearchVM: @unchecked Sendable {
    public var query: String = ""
    public var searchResults: [Song] = []
    public var matchedAlbums: [Album] = []
    public var matchedArtists: [Artist] = []
    public var searchHistory: [String] = ["The Weeknd", "After Hours", "Daft Punk", "Pop Hits"]
    public var isSearching: Bool = false
    public var categories: [MusicCategory] = MockData.sampleCategories
    
    public init() {}
    
    public func performSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            searchResults = []
            matchedAlbums = []
            matchedArtists = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchResults = MockData.sampleSongs.filter {
            $0.title.lowercased().contains(q) ||
            $0.artistName.lowercased().contains(q) ||
            ($0.albumTitle?.lowercased().contains(q) ?? false)
        }
        
        matchedAlbums = MockData.sampleAlbums.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
        
        matchedArtists = MockData.sampleArtists.filter {
            $0.name.lowercased().contains(q)
        }
    }
}

// MARK: - SongVM (Matches Demus.SongVM)
@Observable
public final class SongVM: @unchecked Sendable {
    public var volume: Double = 0.75
    public var isLiked: Bool = false
    
    public init() {}
}
