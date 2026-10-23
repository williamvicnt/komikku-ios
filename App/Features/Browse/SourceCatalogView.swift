import SwiftUI
import SwiftData
import KomikkuCore

enum CatalogMode: String, CaseIterable, Identifiable {
    case popular = "Popular"
    case latest = "Latest"
    var id: String { rawValue }
}

/// Port of Komikku's `BrowseSourceScreenModel`: popular / latest / search with paging.
@MainActor
@Observable
final class CatalogModel {
    private(set) var mangas: [SManga] = []
    private(set) var isLoading = false
    private(set) var hasNextPage = true
    private(set) var errorMessage: String?

    var mode: CatalogMode = .popular
    var query = ""
    var filters: FilterList

    private let source: any Source
    private var page = 0
    private var generation = 0   // invalidates in-flight requests when the query changes

    init(source: any Source) {
        self.source = source
        self.filters = source.filterList()
    }

    var supportsLatest: Bool { source.supportsLatest }
    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    func reload() async {
        generation += 1
        page = 0
        mangas = []
        hasNextPage = true
        errorMessage = nil
        await loadMore()
    }

    func loadMoreIfNeeded(current manga: SManga) async {
        guard manga == mangas.last else { return }
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasNextPage else { return }
        isLoading = true
        let token = generation
        let nextPage = page + 1
        defer { if token == generation { isLoading = false } }
        do {
            let result: MangasPage
            if isSearching || filters != source.filterList() {
                result = try await source.searchManga(page: nextPage, query: query, filters: filters)
            } else if mode == .latest {
                result = try await source.latestUpdates(page: nextPage)
            } else {
                result = try await source.popularManga(page: nextPage)
            }
            guard token == generation else { return }
            // Sources can repeat entries across pages; keep first occurrence only.
            let known = Set(mangas.map(\.url))
            mangas += result.mangas.filter { !known.contains($0.url) }
            hasNextPage = result.hasNextPage
            page = nextPage
        } catch {
            guard token == generation else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct SourceCatalogView: View {
    let sourceID: Int64
    @Environment(\.sourceManager) private var sources

    var body: some View {
        if let source = sources.source(id: sourceID) {
            CatalogContent(source: source)
        } else {
            ContentUnavailableView("Source not found", systemImage: "exclamationmark.triangle")
        }
    }
}

private struct CatalogContent: View {
    let source: any Source
    @State private var model: CatalogModel
    @State private var showingFilters = false

    init(source: any Source) {
        self.source = source
        _model = State(initialValue: CatalogModel(source: source))
    }

    var body: some View {
        ScrollView {
            if source.supportsLatest && !model.isSearching {
                Picker("Mode", selection: $model.mode) {
                    ForEach(CatalogMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            LazyVGrid(columns: mangaGridColumns, spacing: 14) {
                ForEach(model.mangas, id: \.url) { manga in
                    NavigationLink(value: MangaRoute(source: source.id, manga: manga)) {
                        MangaGridCell(urlString: manga.thumbnailURL, title: manga.title)
                    }
                    .buttonStyle(.plain)
                    .task { await model.loadMoreIfNeeded(current: manga) }
                }
            }
            .padding(.horizontal)

            if model.isLoading {
                ProgressView().padding()
            }
            if let message = model.errorMessage {
                VStack(spacing: 8) {
                    Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Retry") { Task { await model.reload() } }
                }
                .padding()
            }
        }
        .navigationTitle(source.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.query, prompt: "Search \(source.name)")
        .onSubmit(of: .search) { Task { await model.reload() } }
        .toolbar {
            if !model.filters.isEmpty {
                Button("Filters", systemImage: "line.3.horizontal.decrease.circle") { showingFilters = true }
            }
        }
        .sheet(isPresented: $showingFilters) {
            FiltersSheet(filters: $model.filters) {
                showingFilters = false
                Task { await model.reload() }
            }
        }
        .task { if model.mangas.isEmpty { await model.reload() } }
        .onChange(of: model.mode) { Task { await model.reload() } }
        .onChange(of: model.query) {
            // Clearing the search box returns to the popular/latest listing.
            if model.query.isEmpty { Task { await model.reload() } }
        }
    }
}
