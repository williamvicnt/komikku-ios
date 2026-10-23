import Foundation

/// Port of `SChapter`.
public struct SChapter: Codable, Hashable, Sendable {
    public var url: String
    public var name: String
    /// -1 means "unknown", as in Komikku.
    public var chapterNumber: Double
    public var scanlator: String?
    /// Upload time in milliseconds since epoch (0 = unknown), as in Komikku.
    public var dateUpload: Int64

    public init(
        name: String,
        url: String,
        dateUpload: Int64 = 0,
        chapterNumber: Double = -1,
        scanlator: String? = nil
    ) {
        self.url = url
        self.name = name
        self.dateUpload = dateUpload
        self.chapterNumber = chapterNumber
        self.scanlator = scanlator
    }

    public var uploadDate: Date? {
        dateUpload > 0 ? Date(timeIntervalSince1970: TimeInterval(dateUpload) / 1000) : nil
    }
}

/// Port of `SMangaUpdate`: details and/or chapters fetched together.
public struct SMangaUpdate: Sendable {
    public var manga: SManga
    public var chapters: [SChapter]

    public init(manga: SManga, chapters: [SChapter]) {
        self.manga = manga
        self.chapters = chapters
    }
}
