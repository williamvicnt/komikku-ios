import SwiftUI
import KomikkuCore

// MARK: Environment

private struct SourceManagerKey: EnvironmentKey {
    static let defaultValue = SourceManager()
}

extension EnvironmentValues {
    var sourceManager: SourceManager {
        get { self[SourceManagerKey.self] }
        set { self[SourceManagerKey.self] = newValue }
    }
}

// MARK: Navigation routes

/// A manga reached from a library grid or a source catalog.
struct MangaRoute: Hashable {
    let source: Int64
    let manga: SManga
}

struct SourceRoute: Hashable {
    let sourceID: Int64
}

extension View {
    /// Every tab's NavigationStack needs to know how to open a manga.
    func mangaDestination() -> some View {
        navigationDestination(for: MangaRoute.self) { MangaDetailView(route: $0) }
    }
}
