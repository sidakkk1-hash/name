import Foundation
import SwiftUI

// MARK: - TopResultItem (Apple Music Search Top Result)
public enum TopResultItem: Identifiable, Hashable, Sendable {
    case artist(Artist)
    case album(Album)
    case song(Song)
    case playlist(Playlist)
    
    public var id: String {
        switch self {
        case .artist(let a): return "artist-\(a.id)"
        case .album(let a): return "album-\(a.id)"
        case .song(let s): return "song-\(s.id)"
        case .playlist(let p): return "playlist-\(p.id)"
        }
    }
}

// MARK: - AppRoute (Global Hierarchical Navigation Route)
public enum AppRoute: Hashable, Sendable {
    case artist(String)
    case album(String)
    case playlist(String)
}

// MARK: - PlaybackState (Authoritative AVFoundation Playback Lifecycle)
public enum PlaybackState: Equatable, Sendable {
    case idle
    case resolving
    case buffering
    case playing
    case paused
    case failed(String)
}

// MARK: - Song Model (Matches Demus Demus4Song Binary Metadata)
public struct Song: Identifiable, Hashable, Codable, Sendable {
    public let id: String // YouTube VideoId or Stream ID
    public var videoId: String { id }
    public var title: String
    public var artistId: String
    public var artistBrowseId: String?
    public var artistName: String
    public var albumId: String?
    public var albumBrowseId: String? {
        get { albumId }
        set { albumId = newValue }
    }
    public var albumTitle: String?
    public var albumName: String? {
        get { albumTitle }
        set { albumTitle = newValue }
    }
    public var artworkURL: URL?
    public var duration: TimeInterval
    public var streamURL: URL?
    public var isFavorite: Bool
    public var lyrics: String?
    public var trackNumber: Int?
    public var isExplicit: Bool
    
    public var formattedDuration: String {
        guard duration > 0 else { return "" }
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public init(
        id: String,
        title: String,
        artistId: String = "artist-yt",
        artistBrowseId: String? = nil,
        artistName: String,
        albumId: String? = nil,
        albumBrowseId: String? = nil,
        albumTitle: String? = nil,
        albumName: String? = nil,
        artworkURL: URL? = nil,
        duration: TimeInterval = 0,
        streamURL: URL? = nil,
        isFavorite: Bool = false,
        lyrics: String? = nil,
        trackNumber: Int? = nil,
        isExplicit: Bool = false
    ) {
        self.id = id
        self.title = title
        let resolvedArtistBrowseId = artistBrowseId ?? (artistId.hasPrefix("UC") || artistId.hasPrefix("FEmusic_") ? artistId : nil)
        self.artistBrowseId = resolvedArtistBrowseId
        self.artistId = artistId != "artist-yt" ? artistId : (resolvedArtistBrowseId ?? "artist-yt")
        self.artistName = artistName
        let resolvedAlbumId = albumBrowseId ?? albumId
        self.albumId = resolvedAlbumId
        self.albumTitle = albumName ?? albumTitle
        self.artworkURL = artworkURL
        self.duration = duration
        self.streamURL = streamURL
        self.isFavorite = isFavorite
        self.lyrics = lyrics
        self.trackNumber = trackNumber
        self.isExplicit = isExplicit
    }
}

// MARK: - Album Model (Matches Demus.Album)
public struct Album: Identifiable, Hashable, Codable, Sendable {
    public let id: String // YouTube Music browseId (e.g. MPREb_...)
    public var browseId: String { id }
    public var title: String
    public var artist: String
    public var artistName: String {
        get { artist }
        set { artist = newValue }
    }
    public var artistId: String?
    public var artistBrowseId: String? {
        get { artistId }
        set { artistId = newValue }
    }
    public var artworkURL: URL?
    public var songs: [Song]
    public var releaseDate: String?
    public var year: String?
    public var albumType: String?
    public var trackCount: Int?
    public var descriptionText: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        artistName: String? = nil,
        artistId: String? = nil,
        artistBrowseId: String? = nil,
        artworkURL: URL? = nil,
        songs: [Song] = [],
        releaseDate: String? = nil,
        year: String? = nil,
        albumType: String? = nil,
        trackCount: Int? = nil,
        descriptionText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artistName ?? artist
        self.artistId = artistBrowseId ?? artistId
        self.artworkURL = artworkURL
        self.songs = songs
        self.releaseDate = releaseDate
        self.year = year ?? releaseDate
        self.albumType = albumType
        self.trackCount = trackCount ?? (songs.isEmpty ? nil : songs.count)
        self.descriptionText = descriptionText
    }
}

// MARK: - Artist Model (Matches Demus.Artist)
public struct Artist: Identifiable, Hashable, Codable, Sendable {
    public let id: String // YouTube Music browseId (e.g. UC...)
    public var browseId: String { id }
    public var name: String
    public var artworkURL: URL?
    public var heroImageURL: URL?
    public var bio: String?
    public var subscribers: String?
    public var topSongs: [Song]
    public var albums: [Album]
    public var singles: [Album]
    public var latestRelease: Album?
    public var relatedArtists: [Artist]
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        artworkURL: URL? = nil,
        heroImageURL: URL? = nil,
        bio: String? = nil,
        subscribers: String? = nil,
        topSongs: [Song] = [],
        albums: [Album] = [],
        singles: [Album] = [],
        latestRelease: Album? = nil,
        relatedArtists: [Artist] = []
    ) {
        self.id = id
        self.name = name
        self.artworkURL = artworkURL
        self.heroImageURL = heroImageURL ?? artworkURL
        self.bio = bio
        self.subscribers = subscribers
        self.topSongs = topSongs
        self.albums = albums
        self.singles = singles
        self.latestRelease = latestRelease
        self.relatedArtists = relatedArtists
    }
}

// MARK: - Playlist Model (Matches Demus Demus8Playlist)
public struct Playlist: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var browseId: String { id }
    public var playlistId: String { id }
    public var title: String
    public var author: String?
    public var descriptionText: String?
    public var artworkURL: URL?
    public var songs: [Song]
    public var isUserCreated: Bool
    public var createdDate: Date
    public var trackCount: Int?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        author: String? = nil,
        descriptionText: String? = nil,
        artworkURL: URL? = nil,
        songs: [Song] = [],
        isUserCreated: Bool = true,
        createdDate: Date = Date(),
        trackCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.descriptionText = descriptionText
        self.artworkURL = artworkURL
        self.songs = songs
        self.isUserCreated = isUserCreated
        self.createdDate = createdDate
        self.trackCount = trackCount ?? (songs.isEmpty ? nil : songs.count)
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
    public var accentTheme: AppAccentTheme = .appleRed
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
