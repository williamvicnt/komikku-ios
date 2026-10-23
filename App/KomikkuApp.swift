import SwiftUI
import SwiftData
import KomikkuCore

@main
struct KomikkuApp: App {
    private let container: ModelContainer
    private let sourceManager: SourceManager

    init() {
        do {
            container = try ModelContainer(
                for: MangaEntity.self, ChapterEntity.self, CategoryEntity.self, HistoryEntity.self
            )
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        // Register every compiled-in source here. iOS cannot load extensions at runtime,
        // so adding a source means adding a Swift type conforming to `Source` and listing it.
        sourceManager = SourceManager(sources: [
            SampleSource(),
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.sourceManager, sourceManager)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
            UpdatesView()
                .tabItem { Label("Updates", systemImage: "sparkles") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
            BrowseView()
                .tabItem { Label("Browse", systemImage: "globe") }
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}
