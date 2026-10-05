# DemusRedesign (SwiftUI Reconstruction & Redesign)

This project reconstructs the UI architecture of the **Demus** music streaming app (v2.0.22) in pure **SwiftUI (iOS 18+)** based on binary reverse-engineering of its nominal types and reflection metadata.

---

## 📁 Project Architecture

```
DemusRedesign/
├── Package.swift                  # Swift Package Manager manifest (iOS 18+)
├── project.yml                    # XcodeGen spec for generating native .xcodeproj
├── Sources/
│   └── DemusRedesign/
│       ├── App.swift              # @main DemusRedesignApp
│       ├── Models/                # Recreated models (Song, Album, Artist, Playlist, QueueItem, PlayerBackground, AppOptions)
│       ├── Playback/              # PlayerEngine & queue state management
│       ├── ViewModels/            # MainTVM, SearchVM, SongVM
│       ├── Components/            # SongThumbnailV, SongProgressBar, PlaybackToolbar, VisualEffectView
│       ├── Theme/                 # AppleMusicTheme tokens & colors (#FA243C)
│       └── Views/
│           ├── Navigation/        # MainTV (Root TabView)
│           ├── Player/            # CompactPlayer (Mini Player) & SongV (Now Playing)
│           ├── Home/              # ExploreV (Featured & Top Songs)
│           ├── Search/            # SearchV (Search bar & results)
│           ├── Library/           # SongsV
│           ├── Playlists/         # PlaylistsV
│           └── Settings/          # SettingsV
└── Tests/
    └── DemusRedesignTests/        # Unit tests
```

---

## 🚀 How to Build & Run

### 1. In Xcode (macOS):
- Double click [`Package.swift`](file:///C:/Users/sidak/.gemini/antigravity-ide/scratch/DemusRedesign/Package.swift) or open folder in Xcode.
- Select target `DemusRedesign` -> Select an iOS 18 simulator or device -> Run (`⌘R`).

### 2. Generate `.xcodeproj` via XcodeGen:
```bash
brew install xcodegen
xcodegen generate
open DemusRedesign.xcodeproj
```

---

## 🎯 Binary Type Mapping

| Reconstructed Type | Demus Binary Target | Purpose |
| :--- | :--- | :--- |
| `DemusAppRootView` / `App` | `@main DemusApp` | App lifecycle entry |
| `MainTV` | `Demus.MainTV` | Root Tab Bar controller |
| `MainTVM` | `_TtC5Demus7MainTVM` | Tab selection & modal sheet coordinator |
| `CompactPlayer` | `Demus.CompactPlayer` | Floating mini-player |
| `SongV` | `Demus.SongV` | Full Now Playing presentation |
| `PlaybackToolbar` | `Demus.PlaybackToolbar` | Media playback buttons |
| `SongProgressBar` | `Demus.SongProgressBar` | Scrubber timeline slider |
| `PlayerBackground` | `Demus.PlayerBackground` | Artwork background mode |
| `ExploreV` | `Demus.ExploreV` | Discover / Listen Now tab |
| `SearchV` | `Demus.SearchV` | Search screen |
| `SongsV` | `Demus.SongsV` | Songs list |
| `PlaylistsV` | `Demus.PlaylistsV` | Playlists collection |
| `SettingsV` | `Demus.SettingsV` | Settings & customization |
