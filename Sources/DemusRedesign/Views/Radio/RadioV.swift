import SwiftUI

// MARK: - RadioV (Apple Music Radio Screen)
/// Recreates the authentic iOS Apple Music Radio tab (Screenshots 1, 2, 3).
/// Features Apple Music 1, Hits, Country, Club, Chill badge grids,
/// "Listen to Live Radio for Free" featured shows, glowing neon "Non-Stop Music" genre stations (Bollywood, Punjabi, Tamil),
/// and international live broadcasts.
public struct RadioV: View {
    @Bindable public var player: PlayerEngine = .shared
    @State private var isSettingsPresented: Bool = false
    
    public init() {}
    
    // Station Badges data
    private let badges: [RadioBadge] = [
        RadioBadge(id: "am1", title: "1", subtitle: "Apple Music Radio", color: .red, type: .number),
        RadioBadge(id: "hits", title: "HITS\nHITS\nHITS", subtitle: "Apple Music Radio", color: Color(red: 0.1, green: 0.65, blue: 1.0), type: .text),
        RadioBadge(id: "country", title: "COUNTRY", subtitle: "Apple Music Radio", color: Color(red: 0.95, green: 0.75, blue: 0.2), type: .star),
        RadioBadge(id: "musica", title: "MÚSICA\nUNO", subtitle: "Apple Music Radio", color: Color(red: 0.95, green: 0.3, blue: 0.65), type: .text),
        RadioBadge(id: "club", title: "club", subtitle: "Apple Music Radio", color: .black, type: .bubble),
        RadioBadge(id: "chill", title: "Chill", subtitle: "Apple Music Radio", color: Color(red: 0.2, green: 0.6, blue: 0.95), type: .text)
    ]
    
    // Neon Genre Stations (Screenshot 2)
    private let neonGenres: [NeonGenre] = [
        NeonGenre(id: "bollywood", title: "Bollywood", query: "Bollywood Hits Radio", glowColor: Color(red: 0.75, green: 0.3, blue: 0.95)),
        NeonGenre(id: "punjabi", title: "Punjabi", query: "Punjabi Top Hits Radio", glowColor: Color(red: 0.95, green: 0.45, blue: 0.2)),
        NeonGenre(id: "tamil", title: "Tamil", query: "Tamil Hits Radio", glowColor: Color(red: 0.85, green: 0.35, blue: 0.75)),
        NeonGenre(id: "hiphop", title: "Hip-Hop", query: "Hip Hop Essentials Radio", glowColor: Color(red: 0.3, green: 0.6, blue: 0.95)),
        NeonGenre(id: "chill", title: "Chill / Lo-Fi", query: "Chillhop Lo-Fi Beats", glowColor: Color(red: 0.3, green: 0.85, blue: 0.75))
    ]
    
    // Featured Live Shows
    private let featuredShows: [FeaturedShow] = [
        FeaturedShow(
            id: "dotty",
            title: "Dotty Show",
            curator: "The Dotty Show",
            description: "Baby Keem, Drake, Don Toliver",
            bannerColor: Color(red: 0.08, green: 0.32, blue: 0.22),
            query: "Baby Keem Drake Don Toliver"
        ),
        FeaturedShow(
            id: "soulection",
            title: "Soulection",
            curator: "Episode 749",
            description: "Joe and Andrés celebrate 15 years",
            bannerColor: Color(red: 0.15, green: 0.22, blue: 0.38),
            query: "Soulection Radio Joe Kay"
        ),
        FeaturedShow(
            id: "vince",
            title: "5 On Fridays",
            curator: "With Vince Staples",
            description: "Turn on both phones for this",
            bannerColor: Color(red: 0.85, green: 0.65, blue: 0.1),
            query: "Vince Staples Radio"
        )
    ]
    
    // International Stations
    private let internationalStations: [InternationalStation] = [
        InternationalStation(id: "virgin", name: "Virgin Radio Italy", subtitle: "Style Rock", logoColor: Color(red: 0.85, green: 0.15, blue: 0.15), query: "Virgin Radio Italy Rock"),
        InternationalStation(id: "nova", name: "Nova 100", subtitle: "TuneIn", logoColor: Color(red: 0.15, green: 0.35, blue: 0.85), query: "Nova 100 Radio Australia"),
        InternationalStation(id: "rum", name: "RUM Radio", subtitle: "TuneIn", logoColor: Color(red: 0.65, green: 0.15, blue: 0.25), query: "RUM Radio")
    ]
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Top Red Promo Banner (Screenshot 1)
                    promoBanner
                        .padding(.horizontal, 16)
                    
                    // Header Bar (Radio title + profile avatar)
                    HStack {
                        Text("Radio")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
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
                    .padding(.horizontal, 16)
                    
                    // Grid of 6 Station Badges (Screenshot 1)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(badges) { badge in
                            stationBadgeView(badge: badge)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Listen to Live Radio for Free (Screenshot 1)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Listen to Live Radio for Free")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(featuredShows) { show in
                                    featuredShowCard(show: show)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Non-Stop Music (Neon Genre Radios - Screenshot 2)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Non-Stop Music")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(neonGenres) { genre in
                                    neonGenreCard(genre: genre)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // International Broadcasters (Screenshot 3)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("International Broadcasters")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(internationalStations) { station in
                                    internationalStationCard(station: station)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Space for floating mini player & tab bar
                    Color.clear.frame(height: 120)
                }
                .padding(.top, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $isSettingsPresented) {
                SettingsV()
            }
        }
    }
    
    // MARK: - Top Promo Banner
    private var promoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 13, weight: .bold))
                    Text("Music")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                
                Text("Play & download all the music you want")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.98, green: 0.15, blue: 0.28))
        )
    }
    
    // MARK: - Station Badge View
    private func stationBadgeView(badge: RadioBadge) -> some View {
        Button {
            triggerStationPlay(query: "\(badge.title) Radio")
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                    
                    VStack(spacing: 2) {
                        Spacer()
                        if badge.type == .number {
                            Text(badge.title)
                                .font(.system(size: 46, weight: .black, design: .rounded))
                                .foregroundStyle(badge.color)
                        } else if badge.type == .star {
                            ZStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(badge.color)
                                Text(badge.title)
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(.blue)
                            }
                        } else if badge.type == .bubble {
                            Text(badge.title)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(badge.color)
                        } else {
                            Text(badge.title)
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(badge.color)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 8, weight: .bold))
                            Text("Music Radio")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(Color.black.opacity(0.65))
                        .padding(.bottom, 6)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Neon Genre Card (Screenshot 2)
    private func neonGenreCard(genre: NeonGenre) -> some View {
        Button {
            triggerStationPlay(query: genre.query)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
                
                // Subtle Apple Music logo top right
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 2) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 9))
                            Text("Music")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(10)
                    }
                    Spacer()
                }
                
                // Centered glowing neon title
                ZStack {
                    Text(genre.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(genre.glowColor)
                        .blur(radius: 12)
                        .opacity(0.85)
                    
                    Text(genre.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 150, height: 150)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Featured Show Card (Screenshot 1)
    private func featuredShowCard(show: FeaturedShow) -> some View {
        Button {
            triggerStationPlay(query: show.query)
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [show.bannerColor, show.bannerColor.opacity(0.7), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(show.title.uppercased())
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(show.curator)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    
                    Text(show.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                    
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                        Text("Live Now")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .frame(width: 290, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - International Station Card (Screenshot 3)
    private func internationalStationCard(station: InternationalStation) -> some View {
        Button {
            triggerStationPlay(query: station.query)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(station.logoColor)
                    
                    VStack {
                        Text(station.name)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(12)
                    }
                }
                .frame(width: 145, height: 145)
                
                Text(station.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(station.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(width: 145)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Station Play Trigger
    private func triggerStationPlay(query: String) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        
        Task {
            let resp = await SearchService.shared.searchAll(query: query)
            let results = resp.songs
            if !results.isEmpty {
                await MainActor.run {
                    player.playAll(songs: results, startingAt: 0, shuffle: false)
                }
            }
        }
    }
}

// MARK: - Supporting Models
struct RadioBadge: Identifiable {
    enum BadgeType { case number, text, star, bubble }
    let id: String
    let title: String
    let subtitle: String
    let color: Color
    let type: BadgeType
}

struct NeonGenre: Identifiable {
    let id: String
    let title: String
    let query: String
    let glowColor: Color
}

struct FeaturedShow: Identifiable {
    let id: String
    let title: String
    let curator: String
    let description: String
    let bannerColor: Color
    let query: String
}

struct InternationalStation: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let logoColor: Color
    let query: String
}
