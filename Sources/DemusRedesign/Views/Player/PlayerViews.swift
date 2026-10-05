import SwiftUI

// MARK: - CompactPlayer
/// Reconstructed Demus CompactPlayer type backed by modern Apple Music MiniPlayer.
public struct CompactPlayer: View {
    @Bindable public var player: PlayerEngine
    @Bindable public var mainTVM: MainTVM
    
    public init(player: PlayerEngine = .shared, mainTVM: MainTVM = .shared) {
        self.player = player
        self.mainTVM = mainTVM
    }
    
    public var body: some View {
        MiniPlayer(player: player, mainTVM: mainTVM)
    }
}
