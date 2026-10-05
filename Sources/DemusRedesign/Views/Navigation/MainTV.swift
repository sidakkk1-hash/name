import SwiftUI

// MARK: - MainTV (Main Tab View matching Demus.MainTV)
/// Primary tab navigation container adhering to modern Apple Music design.
/// Houses Listen Now, Search, Library Songs, Playlists, and Settings.
/// Features Apple Music red (#FA243C) selection tint and a floating MiniPlayer docked above the tab bar.
public struct MainTV: View {
    @Bindable public var mainTVM: MainTVM = .shared
    @Bindable public var player: PlayerEngine = .shared
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Native Tab View
            TabView(selection: $mainTVM.selectedTab) {
                ExploreV()
                    .tabItem {
                        Label(AppTab.explore.title, systemImage: AppTab.explore.iconName)
                    }
                    .tag(AppTab.explore)
                
                SearchV()
                    .tabItem {
                        Label(AppTab.search.title, systemImage: AppTab.search.iconName)
                    }
                    .tag(AppTab.search)
                
                SongsV()
                    .tabItem {
                        Label(AppTab.songs.title, systemImage: AppTab.songs.iconName)
                    }
                    .tag(AppTab.songs)
                
                PlaylistsV()
                    .tabItem {
                        Label(AppTab.playlists.title, systemImage: AppTab.playlists.iconName)
                    }
                    .tag(AppTab.playlists)
                
                SettingsV()
                    .tabItem {
                        Label(AppTab.settings.title, systemImage: AppTab.settings.iconName)
                    }
                    .tag(AppTab.settings)
            }
            .tint(AppleMusicTheme.accent)
            .onChange(of: mainTVM.selectedTab) { _, _ in
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
            .onAppear {
                #if canImport(UIKit)
                let appearance = UITabBarAppearance()
                appearance.configureWithDefaultBackground()
                appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
                #endif
            }
            
            // Floating MiniPlayer docked immediately above the tab bar
            MiniPlayer(player: player, mainTVM: mainTVM)
                .padding(.bottom, 54)
                .animation(AppleMusicTheme.springAnimation, value: player.currentSong?.id)
        }
        .sheet(isPresented: $mainTVM.isNowPlayingPresented) {
            SongV(player: player, mainTVM: mainTVM)
                .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - DemusAppRootView (App Entry Bridge)
public struct DemusAppRootView: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            MainTV()
            #if canImport(UIKit)
            WKAudioEngineView()
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .allowsHitTesting(false)
            #endif
        }
    }
}

