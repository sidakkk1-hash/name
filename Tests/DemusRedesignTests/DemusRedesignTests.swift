import Testing
@testable import DemusRedesign

@Test func testPlayerInitialization() async throws {
    let player = PlayerEngine()
    #expect(player.currentSong != nil)
    #expect(!player.queue.isEmpty)
}
