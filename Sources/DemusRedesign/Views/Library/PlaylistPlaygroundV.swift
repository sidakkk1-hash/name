import SwiftUI

// MARK: - PlaylistPlaygroundV (Apple Music Playlist Playground - iOS 2026)
/// Natural language mood, genre, and activity playlist generator.
/// Takes a prompt like "late night Punjabi drive" and synthesizes a curated playlist with mood tags.
public struct PlaylistPlaygroundV: View {
    @Bindable public var player: PlayerEngine = .shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var promptText: String = ""
    @State private var isGenerating: Bool = false
    @State private var generatedTitle: String = ""
    @State private var generatedSongs: [Song] = []
    @State private var moodTags: [String] = []
    @State private var hasGenerated: Bool = false
    @State private var isSaved: Bool = false
    
    // Quick prompt inspirations
    private let promptSuggestions = [
        "late night Punjabi drive",
        "gym workout hype bass",
        "rainy day lo-fi chill",
        "90s Bollywood romance",
        "acoustic coffee morning",
        "global hip-hop bangers"
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !hasGenerated {
                        // Generator Input View
                        initialPromptView
                    } else {
                        // Generated Playlist Result View
                        generatedResultView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Playlist Playground")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
    
    // MARK: - Initial Prompt Input View
    private var initialPromptView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What do you want to listen to?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("Describe a vibe, mood, genre, artist, or activity and let Playground curate the tracklist.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.top, 8)
            
            // Text Editor Input Box
            VStack(alignment: .trailing, spacing: 8) {
                TextField("e.g. late night Punjabi drive with bass...", text: $promptText, axis: .vertical)
                    .lineLimit(3...5)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(promptText.isEmpty ? Color.white.opacity(0.12) : Color(red: 0.98, green: 0.15, blue: 0.28).opacity(0.6), lineWidth: 1)
                    )
            }
            
            // Generate Action Button
            Button {
                generatePlaylist(query: promptText)
            } label: {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                        Text("Curating Tracklist...")
                            .font(.system(size: 16, weight: .bold))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                        Text("Create Playlist")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    promptText.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating ?
                    Color.gray.opacity(0.3) :
                    Color(red: 0.98, green: 0.15, blue: 0.28)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(promptText.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
            .buttonStyle(.plain)
            
            // Quick Inspiration Chips
            VStack(alignment: .leading, spacing: 12) {
                Text("OR TRY AN INSPIRATION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .kerning(0.6)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(promptSuggestions, id: \.self) { suggestion in
                        Button {
                            promptText = suggestion
                            generatePlaylist(query: suggestion)
                        } label: {
                            HStack {
                                Text(suggestion)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Generated Result View
    private var generatedResultView: some View {
        VStack(spacing: 20) {
            // Playlist Header Hero Card
            VStack(spacing: 12) {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.15, blue: 0.28).opacity(0.8), Color.purple.opacity(0.7), Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text(generatedTitle)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 8)
                
                // Track Count & Mood Tags
                Text("\(generatedSongs.count) Songs Curated")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                
                // Mood Tags
                HStack(spacing: 8) {
                    ForEach(moodTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.98, green: 0.15, blue: 0.28))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.98, green: 0.15, blue: 0.28).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Primary Play & Save Buttons
            HStack(spacing: 12) {
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    player.playAll(songs: generatedSongs, startingAt: 0, shuffle: false)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15))
                        Text("Play All")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(red: 0.98, green: 0.15, blue: 0.28))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button {
                    savePlaylistToLibrary()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSaved ? "checkmark" : "plus")
                            .font(.system(size: 15, weight: .bold))
                        Text(isSaved ? "Saved" : "Save Playlist")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.14))
                    .foregroundStyle(isSaved ? .green : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaved)
            }
            .padding(.horizontal, 8)
            
            // Regenerate Button
            Button {
                generatePlaylist(query: promptText)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Regenerate with New Tracklist")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 4)
            
            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.vertical, 8)
            
            // Tracklist List
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(generatedSongs.enumerated()), id: \.element.id) { index, song in
                    SongRow(
                        song: song,
                        rank: index + 1,
                        isCurrentPlaying: player.currentSong?.id == song.id
                    ) {
                        player.playAll(songs: generatedSongs, startingAt: index, shuffle: false)
                    }
                }
            }
        }
    }
    
    // MARK: - Generation Logic
    private func generatePlaylist(query: String) {
        let cleanPrompt = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return }
        
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        
        isGenerating = true
        isSaved = false
        
        Task {
            // Query YouTube Music via SearchService
            let response = await SearchService.shared.searchAll(query: "\(cleanPrompt) songs")
            var songs = response.songs
            
            // If less than 10, backfill with related query
            if songs.count < 10 {
                let backfill = await SearchService.shared.searchAll(query: cleanPrompt)
                for s in backfill.songs where !songs.contains(where: { $0.id == s.id }) {
                    songs.append(s)
                }
            }
            
            let finalSongs = Array(songs.prefix(14))
            
            // Extract mood tags
            let words = cleanPrompt.capitalized.components(separatedBy: " ")
            let tags = words.filter { $0.count > 2 }.prefix(3).map { String($0) }
            
            await MainActor.run {
                self.generatedTitle = cleanPrompt.capitalized
                self.generatedSongs = finalSongs
                self.moodTags = Array(tags)
                self.isGenerating = false
                self.hasGenerated = true
            }
        }
    }
    
    // MARK: - Save to Library
    private func savePlaylistToLibrary() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        
        let newPlaylist = Playlist(
            id: UUID().uuidString,
            title: generatedTitle,
            descriptionText: "Curated with Playlist Playground: \(moodTags.joined(separator: " · "))",
            artworkURL: generatedSongs.first?.artworkURL,
            songs: generatedSongs,
            isUserCreated: true
        )
        
        LibraryRepository.shared.createPlaylist(title: generatedTitle)
        if let created = LibraryRepository.shared.playlists.last {
            for song in generatedSongs {
                LibraryRepository.shared.addSong(song, to: created.id)
            }
        }
        
        withAnimation {
            isSaved = true
        }
    }
}
