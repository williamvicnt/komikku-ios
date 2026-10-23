// swift-tools-version: 5.9
import PackageDescription

// KomikkuCore: pure-Swift port of Komikku's `source-api` module
// (models + source contract). It has no UI or persistence dependencies,
// so it can be unit-tested with `swift test` on macOS.
let package = Package(
    name: "KomikkuCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KomikkuCore", targets: ["KomikkuCore"]),
    ],
    targets: [
        .target(name: "KomikkuCore"),
        .testTarget(name: "KomikkuCoreTests", dependencies: ["KomikkuCore"]),
    ]
)
