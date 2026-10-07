import SwiftUI

// MARK: - LibraryV (Authentic Apple Music Library Screen)
/// Matches Apple Music Library layout (Screenshot 4).
/// Features large "Library" navigation title, circular user avatar leading to Settings,
/// iconic Red SF Symbol rows (Playlists, Artists, Albums, Songs, Favorites),
/// and a 2-column "Recently Added" grid.
public struct LibraryV: View {
    @Bindable public var player: PlayerEngine = .shared
    @State private var isSettingsPresented: Bool = false
    @State private var isPlaygroundPresented: Bool = false
    @State private var librarySongs: [Song] = LibraryRepository.shared.librarySongs
    
    public init() {}
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Bar (Large Title + Playlist Playground + Profile Avatar - Screenshot 4)
                    HStack(spacing: 16) {
                        Text("Library")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // Playlist Playground (+) Button
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            isPlaygroundPresented = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color(red: 0.98, green: 0.15, blue: 0.28))
                        }
                        
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            isSettingsPresented = true
                        } label: {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    
                    // Classic Red Apple Music Menu Rows (Screenshot 4)
                    VStack(spacing: 0) {
                        NavigationLink {
                            PlaylistsV()
                        } label: {
                            libraryMenuRow(title: "Playlists", icon: "music.note.list")
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.12))
                            .padding(.leading, 64)
                        
                        NavigationLink {
                            LibraryArtistsListView()
                        } label: {
                            libraryMenuRow(title: "Artists", icon: "mic.fill")
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.12))
                            .padding(.leading, 64)
                        
                        NavigationLink {
                            LibraryAlbumsListView()
                        } label: {
                            libraryMenuRow(title: "Albums", icon: "square.stack.fill")
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.12))
                            .padding(.leading, 64)
                        
                        NavigationLink {
                            SongsV()
                        } label: {
                            libraryMenuRow(title: "Songs", icon: "music.note")
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.12))
                            .padding(.leading, 64)
                        
                        NavigationLink {
                            SongsV(initialShowFavoritesOnly: true)
                        } label: {
                            libraryMenuRow(title: "Favorites", icon: "star.fill")
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Recently Added Section (Screenshot 4)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recently Added")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                        
                        if librarySongs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "music.note.house")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("Music you add will appear here")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(librarySongs.prefix(12)) { song in
                                    Button {
                                        player.play(song: song)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ZStack {
                                                if let url = ImageHelper.highResArtworkURL(from: song.artworkURL, videoId: song.id, resolution: .card) {
                                                    CachedAsyncImage(url: url) { img in
                                                        img
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                    } placeholder: {
                                                        Color.gray.opacity(0.3)
                                                    }
                                                } else {
                                                    Color.gray.opacity(0.3)
                                                }
                                            }
                                            .aspectRatio(1.0, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                                            
                                            Text(song.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            
                                            Text(song.artistName)
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(.white.opacity(0.6))
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Space for floating mini player & tab bar
                    Color.clear.frame(height: 120)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $isSettingsPresented) {
                SettingsV()
            }
            .sheet(isPresented: $isPlaygroundPresented) {
                PlaylistPlaygroundV()
            }
            .onAppear {
                librarySongs = LibraryRepository.shared.librarySongs
            }
        }
    }
    
    // MARK: - Red Apple Music Row
    private func libraryMenuRow(title: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(red: 0.98, green: 0.15, blue: 0.28))
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Library Artists & Albums helper views
public struct LibraryArtistsListView: View {
    @State private var artists: [String] = []
    
    public init() {}
    
    public var body: some View {
        List {
            if artists.isEmpty {
                Text("No Artists in Library")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(artists, id: \.self) { artist in
                    NavigationLink {
                        ArtistV(browseId: artist)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(Color(red: 0.98, green: 0.15, blue: 0.28))
                            Text(artist)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
        }
        .navigationTitle("Artists")
        .onAppear {
            let all = LibraryRepository.shared.librarySongs.map(\.artistName).filter { !$0.isEmpty }
            artists = Array(Set(all)).sorted()
        }
    }
}

public struct LibraryAlbumsListView: View {
    @State private var albums: [String] = []
    
    public init() {}
    
    public var body: some View {
        List {
            if albums.isEmpty {
                Text("No Albums in Library")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(albums, id: \.self) { album in
                    Text(album)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .navigationTitle("Albums")
        .onAppear {
            let all = LibraryRepository.shared.librarySongs.compactMap(\.albumTitle).filter { !$0.isEmpty }
            albums = Array(Set(all)).sorted()
        }
    }
}
