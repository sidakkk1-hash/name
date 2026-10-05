import SwiftUI

// MARK: - ExploreV (Listen Now / Personalized Home Screen)
/// Modern Apple Music "Listen Now" home screen with personalized feeds,
/// Quick Picks, Listen Again, Top Charts, and dynamic glass aesthetics.
public struct ExploreV: View {
    @Bindable public var player: PlayerEngine = .shared
    @State private var exploreContent: ExploreService.ExploreContent = ExploreService.ExploreContent()
    @State private var isLoading: Bool = true
    @State private var isLoginSheetPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Profile & Account Status Header
                    accountStatusHeader
                        .padding(.horizontal, 20)
                        .padding(.top, -6)
                    
                    // Non-logged in banner prompt
                    if !GoogleAccountManager.shared.isLoggedIn {
                        loginPromptCard
                            .padding(.horizontal, 16)
                    }
                    
                    // 1. Personalized Sections (Quick Picks, Listen Again, Mixed For You)
                    if !exploreContent.personalizedSections.isEmpty {
                        ForEach(exploreContent.personalizedSections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(
                                    title: section.title,
                                    subtitle: section.subtitle ?? (section.isPersonalized ? "Based on your tastes" : "Recommendations")
                                )
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 14) {
                                        ForEach(section.songs) { song in
                                            MediaCard(
                                                title: song.title,
                                                subtitle: song.artistName,
                                                artworkURL: song.artworkURL,
                                                cardSize: 155
                                            ) {
                                                player.play(song: song)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    
                    // 2. Featured Playlists (Today's Hits)
                    if !exploreContent.featuredPlaylists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Featured Playlists", subtitle: "Handpicked for Today")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(exploreContent.featuredPlaylists) { playlist in
                                        NavigationLink {
                                            PlaylistDetailV(playlist: playlist)
                                        } label: {
                                            MediaCard(
                                                title: playlist.title,
                                                subtitle: playlist.descriptionText ?? "Playlist",
                                                artworkURL: playlist.artworkURL,
                                                cardSize: 195
                                            ) {
                                                // NavigationLink
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 3. Recently Played (from real user playback history)
                    let history = LibraryRepository.shared.history
                    if !history.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Recently Played")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(history) { song in
                                        MediaCard(
                                            title: song.title,
                                            subtitle: song.artistName,
                                            artworkURL: song.artworkURL,
                                            cardSize: 145
                                        ) {
                                            player.play(song: song)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 4. New Releases / Albums
                    if !exploreContent.newAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "New Releases", subtitle: "Albums & EPs")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(exploreContent.newAlbums) { album in
                                        NavigationLink {
                                            AlbumV(album: album)
                                        } label: {
                                            AlbumCard(album: album, size: 160) {}
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 5. Top Artists
                    if !exploreContent.topArtists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Top Artists", subtitle: "Global Charts")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 18) {
                                    ForEach(exploreContent.topArtists) { artist in
                                        NavigationLink {
                                            ArtistV(artist: artist)
                                        } label: {
                                            ArtistCard(artist: artist, diameter: 130) {}
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 6. Popular Songs (Real Chart Toppers)
                    if !exploreContent.topSongs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Popular Songs", subtitle: "Chart Toppers")
                            
                            LazyVStack(spacing: 8) {
                                ForEach(exploreContent.topSongs.prefix(10)) { song in
                                    SongRow(
                                        song: song,
                                        isCurrentPlaying: player.currentSong?.id == song.id
                                    ) {
                                        player.play(song: song)
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    } else if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(AppleMusicTheme.accent)
                                .padding(.top, 40)
                            Spacer()
                        }
                    }
                }
                .padding(.bottom, 90) // Room for MiniPlayer
            }
            .navigationTitle("Listen Now")
            .sheet(isPresented: $isLoginSheetPresented) {
                GoogleLoginSheet()
            }
            .task {
                let content = await ExploreService.shared.fetchExploreContent()
                self.exploreContent = content
                self.isLoading = false
            }
            .refreshable {
                let content = await ExploreService.shared.fetchExploreContent()
                self.exploreContent = content
            }
        }
    }
    
    // MARK: - Header Profile Indicator
    private var accountStatusHeader: some View {
        HStack {
            if GoogleAccountManager.shared.isLoggedIn {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Personalized for you")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                }
            }
            
            Spacer()
            
            Button {
                isLoginSheetPresented = true
            } label: {
                if let name = GoogleAccountManager.shared.userName, !name.isEmpty {
                    ZStack {
                        Circle()
                            .fill(AppleMusicTheme.accent.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppleMusicTheme.accent)
                    }
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(AppleMusicTheme.accent)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Login Prompt Card (Glassy Banner)
    private var loginPromptCard: some View {
        Button {
            isLoginSheetPresented = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26))
                    .foregroundStyle(AppleMusicTheme.accent)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sync YouTube Music")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppleMusicTheme.label)
                    
                    Text("Log in to get Quick Picks, your favorite artists & custom mixes.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppleMusicTheme.secondaryLabel)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppleMusicTheme.tertiaryLabel)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
