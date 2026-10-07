import SwiftUI

// MARK: - SongCreditsSheet (Apple Music View Credits Sheet - iOS 17+)
/// Displays song attribution: Performing Artists, Songwriters, Production, and Audio Quality specs.
public struct SongCreditsSheet: View {
    public let song: Song
    @Environment(\.dismiss) private var dismiss
    
    public init(song: Song) {
        self.song = song
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section("Performing Artists") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.artistName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Lead Vocals")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Composition & Lyrics") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.artistName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Songwriter & Lyricist")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Production & Engineering") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Original Studio Mastering")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Producer & Sound Design")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Audio Quality Specs") {
                    HStack {
                        Text("Format")
                        Spacer()
                        Text("Lossless (ALAC / AAC)")
                            .foregroundStyle(Color(red: 0.98, green: 0.15, blue: 0.28))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    HStack {
                        Text("Resolution")
                        Spacer()
                        Text("24-bit / 48 kHz")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    HStack {
                        Text("Spatial Audio")
                        Spacer()
                        Text("Dolby Atmos Compatible")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.98, green: 0.15, blue: 0.28))
                }
            }
        }
    }
}
