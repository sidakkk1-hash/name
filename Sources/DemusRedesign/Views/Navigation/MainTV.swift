import SwiftUI

// MARK: - MainTV (Apple Music Floating Island Navigation)
/// Recreates iOS 18 Apple Music Floating Island Navigation (Screenshots 1, 2, 3, 4).
/// Features 4 core tabs: [ Home | Radio | Library | Search ].
/// Houses the Floating Capsule Island Tab Bar and the Floating MiniPlayer docked above it.
public struct MainTV: View {
    @Bindable public var mainTVM: MainTVM = .shared
    @Bindable public var player: PlayerEngine = .shared
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Tabs Container
            Group {
                switch mainTVM.selectedTab {
                case .explore:
                    ExploreV()
                case .radio:
                    RadioV()
                case .songs:
                    LibraryV()
                case .search:
                    SearchV()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Floating Controls: Floating MiniPlayer + Floating Island Tab Bar
            VStack(spacing: 8) {
                // Floating MiniPlayer (Screenshots 1-4)
                if player.currentSong != nil {
                    MiniPlayer(player: player, mainTVM: mainTVM)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Floating Capsule Island Tab Bar (Screenshots 1-4)
                floatingIslandTabBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
            }
            .animation(AppleMusicTheme.springAnimation, value: player.currentSong?.id)
            .animation(AppleMusicTheme.springAnimation, value: mainTVM.selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $mainTVM.isNowPlayingPresented) {
            SongV(player: player, mainTVM: mainTVM)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $mainTVM.isQueuePresented) {
            QueueV(player: player)
                .presentationBackground(.ultraThinMaterial)
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Floating Island Capsule Tab Bar (Screenshots 1-4)
    private var floatingIslandTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = mainTVM.selectedTab == tab
                
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        mainTVM.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color(red: 0.98, green: 0.15, blue: 0.28) : Color.white.opacity(0.85))
                        
                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color(red: 0.98, green: 0.15, blue: 0.28) : Color.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                                    .matchedGeometryEffect(id: "selectedTabCapsule", in: tabNamespace)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 62)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                
                Capsule()
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.75))
                
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
            }
        )
        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
    
    @Namespace private var tabNamespace
}

// MARK: - DemusAppRootView (App Entry Bridge)
public struct DemusAppRootView: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            #if canImport(UIKit)
            WKEmbedAudioEngineView()
                .frame(width: 320, height: 240)
                .allowsHitTesting(false)
                .zIndex(0)
            #endif
            MainTV()
                .zIndex(1)
        }
    }
}
