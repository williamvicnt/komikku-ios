import Foundation
import SwiftData
import KomikkuCore

/// Port of the data/domain interactors Komikku uses for library state
/// (GetManga, NetworkToLocalManga, SyncChaptersWithSource, UpdateChapter, UpsertHistory...).
@MainActor
final class LibraryRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Manga

    /// Port of `NetworkToLocalManga`: find the local row for a source manga or create it.
    func localManga(source: Int64, from sManga: SManga) -> MangaEntity {
        let url = sManga.url
        let descriptor = FetchDescriptor<MangaEntity>(
            predicate: #Predicate { $0.source == source && $0.url == url }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.apply(sManga)
            return existing
        }
        let created = MangaEntity(source: source, from: sManga)
        context.insert(created)
        return created
    }

    func setFavorite(_ manga: MangaEntity, _ favorite: Bool) {
        manga.favorite = favorite
        if favorite { manga.dateAdded = .now }
        save()
    }

    // MARK: Chapters

    /// Port of `SyncChaptersWithSource`: new chapters are inserted, known ones updated
    /// (read/bookmark/progress preserved), and chapters the source no longer lists removed.
    /// `sourceChapters` must be in source order (newest first, Komikku's convention).
    @discardableResult
    func syncChapters(_ sourceChapters: [SChapter], into manga: MangaEntity) -> [ChapterEntity] {
        let existing = Dictionary(manga.chapters.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var added: [ChapterEntity] = []

        for (order, sChapter) in sourceChapters.enumerated() where seen.insert(sChapter.url).inserted {
            if let chapter = existing[sChapter.url] {
                chapter.name = sChapter.name
                chapter.scanlator = sChapter.scanlator
                chapter.sourceOrder = order
                if sChapter.chapterNumber >= 0 { chapter.chapterNumber = sChapter.chapterNumber }
                if let date = sChapter.uploadDate { chapter.dateUpload = date }
            } else {
                let chapter = ChapterEntity(from: sChapter, sourceOrder: order)
                chapter.manga = manga
                context.insert(chapter)
                added.append(chapter)
            }
        }

        for chapter in manga.chapters where !seen.contains(chapter.url) {
            context.delete(chapter)
        }
        manga.lastUpdate = .now
        save()
        return added
    }

    // MARK: Reading state

    func setRead(_ chapter: ChapterEntity, _ read: Bool) {
        chapter.read = read
        if read { chapter.lastPageRead = 0 }
        save()
    }

    func setBookmark(_ chapter: ChapterEntity, _ bookmark: Bool) {
        chapter.bookmark = bookmark
        save()
    }

    func saveProgress(_ chapter: ChapterEntity, page: Int, finished: Bool) {
        chapter.lastPageRead = finished ? 0 : page
        if finished { chapter.read = true }
        save()
    }

    /// Port of `UpsertHistory`: one history row per chapter, accumulating read time.
    func recordHistory(for chapter: ChapterEntity, readMillis: Int64) {
        if let history = chapter.history {
            history.lastRead = .now
            history.timeRead += readMillis
        } else {
            let history = HistoryEntity(chapter: chapter, lastRead: .now, timeRead: readMillis)
            context.insert(history)
            chapter.history = history
        }
        save()
    }

    func removeHistory(_ history: HistoryEntity) {
        context.delete(history)
        save()
    }

    // MARK: Categories

    func addCategory(named name: String) {
        let nextSort = ((try? context.fetch(FetchDescriptor<CategoryEntity>()))?.map(\.sort).max() ?? -1) + 1
        context.insert(CategoryEntity(name: name, sort: nextSort))
        save()
    }

    func save() {
        do { try context.save() } catch { assertionFailure("SwiftData save failed: \(error)") }
    }
}
