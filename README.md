# Komikku for iOS (unofficial port)

SwiftUI + SwiftData port of the core of [Komikku](https://github.com/komikku-app/komikku)
(Android manga reader). **Status: first skeleton, written without a Swift toolchain and not yet
compiled or run.** Expect a handful of compile errors on first build in Xcode.

## Requirements
- Mac with Xcode 15.4+ (iOS 17 SDK), [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build
```sh
swift test                      # core package tests (macOS)
xcodegen generate
open Komikku.xcodeproj          # set your Team + bundle id, run on simulator
```

## Building without a Mac (GitHub Actions)
`.github/workflows/ci.yml` runs `swift test`, generates the project with XcodeGen and builds
for the iOS Simulator on a macOS runner (no signing) on every push. Compile errors appear in the
job summary and the full logs are uploaded as the `build-logs` artifact. It verifies that the app
builds; installing it on an iPhone still needs a Mac with Xcode and an Apple ID.

## Layout
| Path | Ports from Komikku | Notes |
|------|--------------------|-------|
| `Sources/KomikkuCore` | `source-api` | `Source` protocol, `HTTPSource` base class, models, filters, `SourceManager`, `SourceID` (same IDs as Android) |
| `App/Persistence` | `data` (`*.sq`) | SwiftData entities mirroring mangas/chapters/categories/history + `LibraryRepository` |
| `App/Features` | `presentation` + `ui` | Library, Browse (+ generic filters sheet), Manga, Reader, History, Updates, More |

## Sources
Android Komikku loads sources from extension APKs at runtime. iOS cannot load third-party
code, so sources are compiled in. To add one: subclass `HTTPSource` (or implement `Source`)
and register it in `KomikkuApp.init`. `SampleSource` is an offline demo; remove it for release.
Only add sources for content you have the right to access.

## Not implemented yet
Downloads/offline reading, trackers, backups/restore, scheduled library updates, categories
management UI beyond creation, related manga, local source, WebView/Cloudflare, sync.

## License
Apache-2.0, see `LICENSE` and `NOTICE`.
