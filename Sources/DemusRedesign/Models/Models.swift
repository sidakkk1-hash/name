import Foundation
import SwiftUI

// MARK: - Song Model (Matches Demus Demus4Song Binary Metadata)
public struct Song: Identifiable, Hashable, Codable, Sendable {
    public let id: String // YouTube VideoId or Stream ID
    public var title: String
    public var artistId: String
    public var artistName: String
    public var albumId: String?
    public var albumTitle: String?
    public var artworkURL: URL?
    public var duration: TimeInterval
    public var streamURL: URL?
    public var isFavorite: Bool
    public var lyrics: String?
    
    public init(
        id: String,
        title: String,
        artistId: String = "artist-yt",
        artistName: String,
        albumId: String? = nil,
        albumTitle: String? = nil,
        artworkURL: URL? = nil,
        duration: TimeInterval = 0,
        streamURL: URL? = nil,
        isFavorite: Bool = false,
        lyrics: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artistId = artistId
        self.artistName = artistName
        self.albumId = albumId
        self.albumTitle = albumTitle
        self.artworkURL = artworkURL
        self.duration = duration
        self.streamURL = streamURL
        self.isFavorite = isFavorite
        self.lyrics = lyrics
    }
}

// MARK: - Album Model (Matches Demus.Album)
public struct Album: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var title: String
    public var artist: String
    public var artworkURL: URL?
    public var songs: [Song]
    public var releaseDate: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        artworkURL: URL? = nil,
        songs: [Song] = [],
        releaseDate: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.songs = songs
        self.releaseDate = releaseDate
    }
}

// MARK: - Artist Model (Matches Demus.Artist)
public struct Artist: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var name: String
    public var artworkURL: URL?
    public var topSongs: [Song]
    public var albums: [Album]
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        artworkURL: URL? = nil,
        topSongs: [Song] = [],
        albums: [Album] = []
    ) {
        self.id = id
        self.name = name
        self.artworkURL = artworkURL
        self.topSongs = topSongs
        self.albums = albums
    }
}

// MARK: - Playlist Model (Matches Demus Demus8Playlist)
public struct Playlist: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var title: String
    public var descriptionText: String?
    public var artworkURL: URL?
    public var songs: [Song]
    public var isUserCreated: Bool
    public var createdDate: Date
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        descriptionText: String? = nil,
        artworkURL: URL? = nil,
        songs: [Song] = [],
        isUserCreated: Bool = true,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.artworkURL = artworkURL
        self.songs = songs
        self.isUserCreated = isUserCreated
        self.createdDate = createdDate
    }
}

// MARK: - MusicCategory (For Search Browse Categories)
public struct MusicCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let query: String
    public let gradientColors: [Color]
    public let iconName: String
    
    public init(id: String = UUID().uuidString, title: String, query: String, gradientColors: [Color], iconName: String) {
        self.id = id
        self.title = title
        self.query = query
        self.gradientColors = gradientColors
        self.iconName = iconName
    }
}

// MARK: - QueueItem (Matches Demus Demus9QueueItem)
public struct QueueItem: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var title: String
    public var artistId: String
    public var artistName: String
    public var albumId: String?
    public var albumTitle: String?
    public var artworkURL: URL?
    public var duration: TimeInterval
    public var position: Int
    
    public init(from song: Song, position: Int = 0) {
        self.id = song.id
        self.title = song.title
        self.artistId = song.artistId
        self.artistName = song.artistName
        self.albumId = song.albumId
        self.albumTitle = song.albumTitle
        self.artworkURL = song.artworkURL
        self.duration = song.duration
        self.position = position
    }
}

// MARK: - PlayerBackground Mode (Matches Demus binary enum)
public enum PlayerBackground: String, CaseIterable, Identifiable, Codable, Sendable {
    case `default`
    case oneColor
    case twoColor
    
    public var id: String { rawValue }
}

// MARK: - AppOptions (Derived from Demus Demus10AppOptions metadata)
public struct AppOptions: Codable, Sendable {
    public var playerBackground: PlayerBackground = .default
    public var showSongDurations: Bool = true
    public var showRewindButton: Bool = true
    public var defaultTab: Int = 0
    public var exploreVMode: Int = 0
    public var autoplay: Bool = true
    
    public init() {}
}

// MARK: - Standard Search Browse Categories
public enum SearchCategories {
    public static let all: [MusicCategory] = [
        MusicCategory(
            title: "Spatial Audio",
            query: "Spatial Audio Hits",
            gradientColors: [Color(red: 0.98, green: 0.2, blue: 0.45), Color(red: 0.6, green: 0.1, blue: 0.85)],
            iconName: "waveform.badge.magnifyingglass"
        ),
        MusicCategory(
            title: "Pop Hits",
            query: "Top Pop Songs 2026",
            gradientColors: [Color(red: 0.98, green: 0.45, blue: 0.15), Color(red: 0.95, green: 0.15, blue: 0.35)],
            iconName: "music.note"
        ),
        MusicCategory(
            title: "Hip-Hop / Rap",
            query: "Top Hip Hop Hits",
            gradientColors: [Color(red: 0.2, green: 0.6, blue: 0.95), Color(red: 0.1, green: 0.3, blue: 0.8)],
            iconName: "mic.fill"
        ),
        MusicCategory(
            title: "Electronic & Dance",
            query: "Top EDM Dance Music",
            gradientColors: [Color(red: 0.1, green: 0.85, blue: 0.75), Color(red: 0.05, green: 0.5, blue: 0.7)],
            iconName: "bolt.fill"
        ),
        MusicCategory(
            title: "Chill & Focus",
            query: "Lo-Fi Beats to Relax",
            gradientColors: [Color(red: 0.45, green: 0.75, blue: 0.4), Color(red: 0.2, green: 0.55, blue: 0.5)],
            iconName: "leaf.fill"
        ),
        MusicCategory(
            title: "Rock & Alternative",
            query: "Top Rock Anthems",
            gradientColors: [Color(red: 0.7, green: 0.2, blue: 0.2), Color(red: 0.4, green: 0.1, blue: 0.2)],
            iconName: "guitars.fill"
        ),
        MusicCategory(
            title: "R&B / Soul",
            query: "Modern R&B Hits",
            gradientColors: [Color(red: 0.85, green: 0.3, blue: 0.6), Color(red: 0.5, green: 0.15, blue: 0.45)],
            iconName: "heart.fill"
        ),
        MusicCategory(
            title: "Charts & Global",
            query: "Global Top 50",
            gradientColors: [Color(red: 0.95, green: 0.7, blue: 0.15), Color(red: 0.9, green: 0.4, blue: 0.1)],
            iconName: "chart.line.uptrend.xyaxis"
        )
    ]
}
