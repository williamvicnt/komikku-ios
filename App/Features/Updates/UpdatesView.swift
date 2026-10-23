import SwiftUI
import SwiftData
import KomikkuCore

/// Port of Komikku's Updates tab: recently fetched, unread chapters of library manga.
/// (Chapter fetching on a schedule is not implemented yet; use pull-to-refresh.)
struct UpdatesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.sourceManager) private var sources
    @Query(sort: \ChapterEntity.dateFetch, order: .reverse) private var chapters: [ChapterEntity]
    @Query(filter: #Predicate<MangaEntity> { $0.favorite }) private var library: [MangaEntity]

    @State private var isRefreshing = false

    private var unread: [ChapterEntity] {
        chapters.filter { !$0.read && ($0.manga?.favorite ?? false) }.prefix(200).map { $0 }
    }

    var body: some View {
        NavigationStack {
            List(unread) { chapter in
                if let manga = chapter.manga {
                    NavigationLink(value: MangaRoute(source: manga.source, manga: manga.asSManga)) {
                        HStack(spacing: 12) {
                            CoverImage(urlString: manga.thumbnailURL, title: manga.title)
                                .frame(width: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(manga.title).lineLimit(1)
                                Text(chapter.name).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if unread.isEmpty {
                    ContentUnavailableView("No updates", systemImage: "sparkles",
                                           description: Text("Pull down to check your library for new chapters."))
                }
            }
            .refreshable { await refreshLibrary() }
            .navigationTitle("Updates")
            .mangaDestination()
        }
    }

    /// Port of `LibraryUpdateJob` (foreground only): refresh chapters of every library manga.
    /// Failures of one source do not stop the others, matching Komikku's behaviour.
    private func refreshLibrary() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let repo = LibraryRepository(context: context)
        for manga in library {
            guard let source = sources.source(id: manga.source) else { continue }
            if let list = try? await source.chapterList(manga.asSManga) {
                repo.syncChapters(list, into: manga)
            }
        }
    }
}
