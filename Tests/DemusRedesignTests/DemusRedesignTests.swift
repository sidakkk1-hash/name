import Testing
@testable import DemusRedesign

@Test func testPlayerInitialization() async throws {
    let player = PlayerEngine()
    #expect(player.isPlaying == false)
}

@Test func testSearchService() async throws {
    let results = try await SearchService.shared.search(query: "Blinding Lights")
    #expect(!results.isEmpty)
    #expect(results.first?.title != nil)
}
