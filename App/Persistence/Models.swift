import Foundation
import SwiftData
import KomikkuCore

// SwiftData port of Komikku's SQLDelight tables (mangas, chapters, categories,
// mangas_categories, history). Column names follow the Android schema so a future
// backup importer can map them 1:1.

@Model
final class MangaEntity {
    var source: Int64
    var url: String
    var title: String
    var artist: String?
    var author: String?
    var mangaDescription: String?
    var genre: [String]
    var status: Int
    var thumbnailURL: String?
    var favorite: Bool
    var initialized: Bool
    var dateAdded: Date
    var lastUpdate: Date?
    var viewer: Int          // 0 = default, see ReaderMode
    var chapterFlags: Int
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \ChapterEntity.manga)
    var chapters: [ChapterEntity] = []

    // Many-to-many (Komikku's `mangas_categories` table).
    @Relationship(inverse: \CategoryEntity.mangas)
    var categories: [CategoryEntity] = []

    init(source: Int64, from sManga: SManga) {
        self.source = source
        self.url = sManga.url
        self.title = sManga.title
        self.artist = sManga.artist
        self.author = sManga.author
        self.mangaDescription = sManga.description
        self.genre = sManga.genres ?? []
        self.status = sManga.status.rawValue
        self.thumbnailURL = sManga.thumbnailURL
        self.favorite = false
        self.initialized = sManga.initialized
        self.dateAdded = .now
        self.viewer = 0
        self.chapterFlags = 0
        self.notes = ""
    }

    var mangaStatus: MangaStatus { MangaStatus(rawValue: status) ?? .unknown }

    /// Merge fresh data from the source. Mirrors Komikku: a source never blanks existing
    /// fields, and the title only changes while the manga is not in the library.
    func apply(_ sManga: SManga) {
        if !favorite { title = sManga.title }
        if let value = sManga.artist { artist = value }
        if let value = sManga.author { author = value }
        if let value = sManga.description { mangaDescription = value }
        if let value = sManga.genres { genre = value }
        if let value = sManga.thumbnailURL { thumbnailURL = value }
        status = sManga.status.rawValue
        initialized = initialized || sManga.initialized
    }

    var asSManga: SManga {
        SManga(
            url: url, title: title, artist: artist, author: author,
            description: mangaDescription, genre: genre.joined(separator: ", "),
            status: mangaStatus, thumbnailURL: thumbnailURL, initialized: initialized
        )
    }

    var unreadCount: Int { chapters.filter { !$0.read }.count }
}

@Model
final class ChapterEntity {
    var url: String
    var name: String
    var scanlator: String?
    var read: Bool
    var bookmark: Bool
    var lastPageRead: Int
    var chapterNumber: Double
    var sourceOrder: Int
    var dateFetch: Date
    var dateUpload: Date?

    var manga: MangaEntity?

    @Relationship(deleteRule: .cascade, inverse: \HistoryEntity.chapter)
    var history: HistoryEntity?

    init(from sChapter: SChapter, sourceOrder: Int) {
        self.url = sChapter.url
        self.name = sChapter.name
        self.scanlator = sChapter.scanlator
        self.read = false
        self.bookmark = false
        self.lastPageRead = 0
        self.chapterNumber = sChapter.chapterNumber
        self.sourceOrder = sourceOrder
        self.dateFetch = .now
        self.dateUpload = sChapter.uploadDate
    }

    var asSChapter: SChapter {
        SChapter(
            name: name, url: url,
            dateUpload: dateUpload.map { Int64($0.timeIntervalSince1970 * 1000) } ?? 0,
            chapterNumber: chapterNumber, scanlator: scanlator
        )
    }
}

@Model
final class CategoryEntity {
    var name: String
    var sort: Int
    var hidden: Bool       // Komikku (KMK) addition
    var mangas: [MangaEntity] = []

    init(name: String, sort: Int, hidden: Bool = false) {
        self.name = name
        self.sort = sort
        self.hidden = hidden
    }
}

@Model
final class HistoryEntity {
    var chapter: ChapterEntity?
    var lastRead: Date
    /// Time spent reading, in milliseconds (same unit as Komikku's `time_read`).
    var timeRead: Int64

    init(chapter: ChapterEntity, lastRead: Date = .now, timeRead: Int64 = 0) {
        self.chapter = chapter
        self.lastRead = lastRead
        self.timeRead = timeRead
    }
}

enum ReaderMode: Int, CaseIterable, Identifiable {
    case defaultMode = 0
    case leftToRight = 1
    case rightToLeft = 2
    case vertical = 3
    case webtoon = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .defaultMode: "Default"
        case .leftToRight: "Left to right"
        case .rightToLeft: "Right to left"
        case .vertical: "Vertical"
        case .webtoon: "Webtoon"
        }
    }
}
