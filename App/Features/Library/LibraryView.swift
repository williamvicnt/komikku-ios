import SwiftUI
import SwiftData
import KomikkuCore

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<MangaEntity> { $0.favorite }, sort: \MangaEntity.title)
    private var mangas: [MangaEntity]
    @Query(sort: \CategoryEntity.sort) private var categories: [CategoryEntity]

    @State private var search = ""
    @State private var selectedCategory: CategoryEntity?
    @State private var showingNewCategory = false
    @State private var newCategoryName = ""

    private var visibleMangas: [MangaEntity] {
        mangas.filter { manga in
            let inCategory = selectedCategory.map { category in
                manga.categories.contains { $0.persistentModelID == category.persistentModelID }
            } ?? true
            let matchesSearch = search.isEmpty || manga.title.localizedCaseInsensitiveContains(search)
            return inCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if !categories.isEmpty {
                    categoryChips
                }
                if visibleMangas.isEmpty {
                    ContentUnavailableView(
                        mangas.isEmpty ? "Your library is empty" : "No results",
                        systemImage: "books.vertical",
                        description: Text(mangas.isEmpty ? "Add manga from Browse." : "Try another search or category.")
                    )
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: mangaGridColumns, spacing: 14) {
                        ForEach(visibleMangas) { manga in
                            NavigationLink(value: MangaRoute(source: manga.source, manga: manga.asSManga)) {
                                MangaGridCell(
                                    urlString: manga.thumbnailURL, title: manga.title, badge: manga.unreadCount
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Library")
            .searchable(text: $search, prompt: "Search library")
            .toolbar {
                Button("New category", systemImage: "folder.badge.plus") { showingNewCategory = true }
            }
            .alert("New category", isPresented: $showingNewCategory) {
                TextField("Name", text: $newCategoryName)
                Button("Add") {
                    let name = newCategoryName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { LibraryRepository(context: context).addCategory(named: name) }
                    newCategoryName = ""
                }
                Button("Cancel", role: .cancel) { newCategoryName = "" }
            }
            .mangaDestination()
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip("All", selected: selectedCategory == nil) { selectedCategory = nil }
                ForEach(categories.filter { !$0.hidden }) { category in
                    chip(category.name, selected: selectedCategory?.persistentModelID == category.persistentModelID) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(selected ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
            .foregroundStyle(selected ? .white : .primary)
    }
}
