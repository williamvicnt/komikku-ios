import SwiftUI
import SwiftData
import KomikkuCore

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HistoryEntity.lastRead, order: .reverse) private var history: [HistoryEntity]
    @State private var search = ""

    private var entries: [HistoryEntity] {
        history.filter { entry in
            guard entry.chapter?.manga != nil else { return false }
            return search.isEmpty
                || (entry.chapter?.manga?.title.localizedCaseInsensitiveContains(search) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    if let chapter = entry.chapter, let manga = chapter.manga {
                        NavigationLink(value: MangaRoute(source: manga.source, manga: manga.asSManga)) {
                            HStack(spacing: 12) {
                                CoverImage(urlString: manga.thumbnailURL, title: manga.title)
                                    .frame(width: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(manga.title).lineLimit(2)
                                    Text("\(chapter.name) • \(entry.lastRead.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                LibraryRepository(context: context).removeHistory(entry)
                            }
                        }
                    }
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView("No history", systemImage: "clock",
                                           description: Text("Chapters you read show up here."))
                }
            }
            .navigationTitle("History")
            .searchable(text: $search, prompt: "Search history")
            .mangaDestination()
        }
    }
}
