import Foundation
import SwiftUI

// MARK: - Song Model (Derived from Demus Binary Metadata)
public struct Song: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var title: String
    public var artistId: String
    public var artistName: String
    public var albumId: String?
    public var albumTitle: String?
    public var artworkURL: URL?
    public var duration: TimeInterval
    public var streamURL: URL?
    public var isFavorite: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artistId: String = "artist-1",
        artistName: String,
        albumId: String? = nil,
        albumTitle: String? = nil,
        artworkURL: URL? = nil,
        duration: TimeInterval = 180,
        streamURL: URL? = nil,
        isFavorite: Bool = false
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
    }
}

// MARK: - Album Model
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

// MARK: - Artist Model
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

// MARK: - Playlist Model
public struct Playlist: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var title: String
    public var descriptionText: String?
    public var artworkURL: URL?
    public var songs: [Song]
    public var isUserCreated: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        descriptionText: String? = nil,
        artworkURL: URL? = nil,
        songs: [Song] = [],
        isUserCreated: Bool = true
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.artworkURL = artworkURL
        self.songs = songs
        self.isUserCreated = isUserCreated
    }
}

// MARK: - MusicCategory (For Search Browse Categories)
public struct MusicCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let gradientColors: [Color]
    public let iconName: String
    
    public init(id: String = UUID().uuidString, title: String, gradientColors: [Color], iconName: String) {
        self.id = id
        self.title = title
        self.gradientColors = gradientColors
        self.iconName = iconName
    }
}

// MARK: - QueueItem (Matches Demus.QueueItem metadata)
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

// MARK: - PlayerBackground Mode (Matches Demus.PlayerBackground binary enum)
public enum PlayerBackground: String, CaseIterable, Identifiable, Codable, Sendable {
    case `default`
    case oneColor
    case twoColor
    
    public var id: String { rawValue }
}

// MARK: - AppOptions (Derived from Demus.AppOptions metadata)
public struct AppOptions: Codable, Sendable {
    public var playerBackground: PlayerBackground = .default
    public var showSongDurations: Bool = true
    public var showRewindButton: Bool = true
    public var defaultTab: Int = 0
    public var exploreVMode: Int = 0
    public var autoplay: Bool = true
    
    public init() {}
}

// MARK: - Mock / Sample Data Repository
public enum MockData {
    public static let sampleSongs: [Song] = [
        Song(
            id: "song-1",
            title: "Blinding Lights",
            artistId: "artist-the-weeknd",
            artistName: "The Weeknd",
            albumId: "album-after-hours",
            albumTitle: "After Hours",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800"),
            duration: 200,
            isFavorite: true
        ),
        Song(
            id: "song-2",
            title: "Starboy",
            artistId: "artist-the-weeknd",
            artistName: "The Weeknd ft. Daft Punk",
            albumId: "album-starboy",
            albumTitle: "Starboy",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800"),
            duration: 230,
            isFavorite: false
        ),
        Song(
            id: "song-3",
            title: "Sunroof",
            artistId: "artist-nicky-youre",
            artistName: "Nicky Youre & Dazy",
            albumId: "album-sunroof",
            albumTitle: "Sunroof - Single",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800"),
            duration: 163,
            isFavorite: true
        ),
        Song(
            id: "song-4",
            title: "Save Your Tears",
            artistId: "artist-the-weeknd",
            artistName: "The Weeknd",
            albumId: "album-after-hours",
            albumTitle: "After Hours",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800"),
            duration: 215,
            isFavorite: false
        ),
        Song(
            id: "song-5",
            title: "One More Time",
            artistId: "artist-daft-punk",
            artistName: "Daft Punk",
            albumId: "album-discovery",
            albumTitle: "Discovery",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=800"),
            duration: 320,
            isFavorite: true
        ),
        Song(
            id: "song-6",
            title: "As It Was",
            artistId: "artist-harry-styles",
            artistName: "Harry Styles",
            albumId: "album-harrys-house",
            albumTitle: "Harry's House",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1445985543468-79fbaae99103?w=800"),
            duration: 167,
            isFavorite: false
        )
    ]
    
    public static let sampleAlbums: [Album] = [
        Album(
            id: "album-after-hours",
            title: "After Hours",
            artist: "The Weeknd",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800"),
            songs: [sampleSongs[0], sampleSongs[3]],
            releaseDate: "2020"
        ),
        Album(
            id: "album-starboy",
            title: "Starboy",
            artist: "The Weeknd",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800"),
            songs: [sampleSongs[1]],
            releaseDate: "2016"
        ),
        Album(
            id: "album-discovery",
            title: "Discovery",
            artist: "Daft Punk",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=800"),
            songs: [sampleSongs[4]],
            releaseDate: "2001"
        )
    ]
    
    public static let samplePlaylists: [Playlist] = [
        Playlist(
            id: "pl-today-hits",
            title: "Today's Hits",
            descriptionText: "The biggest songs right now. Updated daily with chart-toppers.",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800"),
            songs: sampleSongs,
            isUserCreated: false
        ),
        Playlist(
            id: "pl-night-drive",
            title: "Night Drive",
            descriptionText: "Late-night synthwave and cinematic pop anthems.",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800"),
            songs: [sampleSongs[0], sampleSongs[1], sampleSongs[4]],
            isUserCreated: true
        ),
        Playlist(
            id: "pl-chill-mix",
            title: "Chill Wave & Lo-Fi",
            descriptionText: "Mellow vibes for study, relaxation, and mindfulness.",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=800"),
            songs: [sampleSongs[2], sampleSongs[5]],
            isUserCreated: true
        ),
        Playlist(
            id: "pl-favorites",
            title: "Favorites",
            descriptionText: "Your loved tracks gathered into one personal collection.",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800"),
            songs: sampleSongs.filter { $0.isFavorite },
            isUserCreated: true
        )
    ]
    
    public static let sampleArtists: [Artist] = [
        Artist(
            id: "artist-the-weeknd",
            name: "The Weeknd",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800"),
            topSongs: [sampleSongs[0], sampleSongs[1], sampleSongs[3]],
            albums: [sampleAlbums[0], sampleAlbums[1]]
        ),
        Artist(
            id: "artist-daft-punk",
            name: "Daft Punk",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=800"),
            topSongs: [sampleSongs[4]],
            albums: [sampleAlbums[2]]
        ),
        Artist(
            id: "artist-nicky-youre",
            name: "Nicky Youre",
            artworkURL: URL(string: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800"),
            topSongs: [sampleSongs[2]],
            albums: []
        )
    ]
    
    public static let sampleCategories: [MusicCategory] = [
        MusicCategory(
            title: "Spatial Audio",
            gradientColors: [Color(red: 0.98, green: 0.2, blue: 0.45), Color(red: 0.6, green: 0.1, blue: 0.85)],
            iconName: "waveform.badge.magnifyingglass"
        ),
        MusicCategory(
            title: "Pop Hits",
            gradientColors: [Color(red: 0.98, green: 0.45, blue: 0.15), Color(red: 0.95, green: 0.15, blue: 0.35)],
            iconName: "music.note"
        ),
        MusicCategory(
            title: "Hip-Hop / Rap",
            gradientColors: [Color(red: 0.2, green: 0.6, blue: 0.95), Color(red: 0.1, green: 0.3, blue: 0.8)],
            iconName: "mic.fill"
        ),
        MusicCategory(
            title: "Electronic & Dance",
            gradientColors: [Color(red: 0.1, green: 0.85, blue: 0.75), Color(red: 0.05, green: 0.5, blue: 0.7)],
            iconName: "bolt.fill"
        ),
        MusicCategory(
            title: "Chill & Focus",
            gradientColors: [Color(red: 0.45, green: 0.75, blue: 0.4), Color(red: 0.2, green: 0.55, blue: 0.5)],
            iconName: "leaf.fill"
        ),
        MusicCategory(
            title: "Rock & Alternative",
            gradientColors: [Color(red: 0.7, green: 0.2, blue: 0.2), Color(red: 0.4, green: 0.1, blue: 0.2)],
            iconName: "guitars.fill"
        ),
        MusicCategory(
            title: "R&B / Soul",
            gradientColors: [Color(red: 0.85, green: 0.3, blue: 0.6), Color(red: 0.5, green: 0.15, blue: 0.45)],
            iconName: "heart.fill"
        ),
        MusicCategory(
            title: "Charts & Decades",
            gradientColors: [Color(red: 0.95, green: 0.7, blue: 0.15), Color(red: 0.9, green: 0.4, blue: 0.1)],
            iconName: "chart.line.uptrend.xyaxis"
        )
    ]
}
