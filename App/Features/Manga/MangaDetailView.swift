import SwiftUI
import SwiftData
import KomikkuCore

/// Port of Komikku's manga screen: header, favourite toggle, chapter list with read state.
struct MangaDetailView: View {
    let route: MangaRoute

    @Environment(\.modelContext) private var context
    @Environment(\.sourceManager) private var sources

    @State private var manga: MangaEntity?
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var readingChapter: ChapterEntity?

    var body: some View {
        ScrollView {
            if let manga {
                VStack(alignment: .leading, spacing: 16) {
                    header(manga)
                    actions(manga)
                    if let description = manga.mangaDescription, !description.isEmpty {
                        Text(description).font(.callout)
                    }
                    if !manga.genre.isEmpty {
                        genreTags(manga.genre)
                    }
                    Divider()
                    chapterList(manga)
                }
                .padding()
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .navigationTitle(route.manga.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refresh() }
        .task { await load() }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding()
                    .onTapGesture { self.errorMessage = nil }
            }
        }
        .fullScreenCover(item: $readingChapter) { chapter in
            ReaderView(chapter: chapter)
        }
    }

    // MARK: Sections

    private func header(_ manga: MangaEntity) -> some View {
        HStack(alignment: .top, spacing: 14) {
            CoverImage(urlString: manga.thumbnailURL, title: manga.title)
                .frame(width: 110)
            VStack(alignment: .leading, spacing: 4) {
                Text(manga.title).font(.title3.bold())
                if let author = manga.author { Text(author).font(.subheadline) }
                if let artist = manga.artist, artist != manga.author {
                    Text(artist).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(manga.mangaStatus.title).font(.caption).foregroundStyle(.secondary)
                if let name = sources.source(id: manga.source)?.name {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func actions(_ manga: MangaEntity) -> some View {
        HStack {
            Button {
                LibraryRepository(context: context).setFavorite(manga, !manga.favorite)
            } label: {
                Label(manga.favorite ? "In library" : "Add to library",
                      systemImage: manga.favorite ? "heart.fill" : "heart")
            }
            .buttonStyle(.borderedProminent)

            if let next = nextUnread(manga) {
                Button {
                    readingChapter = next
                } label: {
                    Label(next.lastPageRead > 0 || manga.chapters.contains(where: \.read) ? "Resume" : "Start",
                          systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
            }
            if isRefreshing { ProgressView() }
        }
    }

    private func genreTags(_ genres: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color(.secondarySystemFill), in: Capsule())
                }
            }
        }
    }

    private func chapterList(_ manga: MangaEntity) -> some View {
        let chapters = sorted(manga.chapters)
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(chapters.count) chapters").font(.headline).padding(.bottom, 8)
            ForEach(chapters) { chapter in
                Button { readingChapter = chapter } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chapter.name)
                                .foregroundStyle(chapter.read ? .secondary : .primary)
                            subtitle(for: chapter)
                        }
                        Spacer()
                        if chapter.bookmark { Image(systemName: "bookmark.fill").foregroundStyle(.tint) }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(chapter.read ? "Mark as unread" : "Mark as read",
                           systemImage: chapter.read ? "eye.slash" : "eye") {
                        LibraryRepository(context: context).setRead(chapter, !chapter.read)
                    }
                    Button(chapter.bookmark ? "Remove bookmark" : "Bookmark",
                           systemImage: "bookmark") {
                        LibraryRepository(context: context).setBookmark(chapter, !chapter.bookmark)
                    }
                }
                Divider()
            }
        }
    }

    private func subtitle(for chapter: ChapterEntity) -> some View {
        var parts: [String] = []
        if let date = chapter.dateUpload { parts.append(date.formatted(date: .abbreviated, time: .omitted)) }
        if chapter.lastPageRead > 0 && !chapter.read { parts.append("Page \(chapter.lastPageRead + 1)") }
        if let scanlator = chapter.scanlator, !scanlator.isEmpty { parts.append(scanlator) }
        return Text(parts.joined(separator: " • ")).font(.caption).foregroundStyle(.secondary)
    }

    // MARK: Data

    private func sorted(_ chapters: [ChapterEntity]) -> [ChapterEntity] {
        chapters.sorted { $0.sourceOrder < $1.sourceOrder }
    }

    /// Oldest unread chapter (source order is newest first, so scan from the end).
    private func nextUnread(_ manga: MangaEntity) -> ChapterEntity? {
        sorted(manga.chapters).last(where: { !$0.read })
    }

    private func load() async {
        guard manga == nil else { return }
        manga = LibraryRepository(context: context).localManga(source: route.source, from: route.manga)
        await refresh()
    }

    /// Port of `MangaScreenModel.fetchAllFromSource`.
    private func refresh() async {
        guard let manga, !isRefreshing else { return }
        guard let source = sources.source(id: manga.source) else {
            errorMessage = "This source is not installed."
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let update = try await source.mangaUpdate(
                manga: manga.asSManga, chapters: [], fetchDetails: true, fetchChapters: true
            )
            let repo = LibraryRepository(context: context)
            manga.apply(update.manga)
            repo.syncChapters(update.chapters, into: manga)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
