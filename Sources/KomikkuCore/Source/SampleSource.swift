import Foundation

/// Offline demo source so the app is usable (and testable) with zero network access.
/// It is also the reference for how a minimal `Source` looks. Remove it in production builds.
///
/// Page images use the custom scheme `sample://<seed>/<page>`; the app's `PageImageView`
/// draws a placeholder for it.
public struct SampleSource: Source {
    public static let sourceID: Int64 = SourceID.make(name: "Sample Source", lang: "en")

    public let id: Int64 = SampleSource.sourceID
    public let name = "Sample Source"
    public let lang = "en"
    public let supportsLatest = true

    private let pageSize = 20
    private let totalPages = 3
    private let chaptersPerManga = 12
    private let pagesPerChapter = 10

    public init() {}

    public func filterList() -> FilterList {
        [
            .header(name: "Sample filters"),
            .select(name: "Status", values: ["Any", "Ongoing", "Completed"], state: 0),
            .checkBox(name: "Only favourites", state: false),
        ]
    }

    public func popularManga(page: Int) async throws -> MangasPage {
        makePage(page: page, offset: 0)
    }

    public func latestUpdates(page: Int) async throws -> MangasPage {
        makePage(page: page, offset: 500)
    }

    public func searchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage {
        let all = makePage(page: page, offset: 0).mangas
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = needle.isEmpty ? all : all.filter { $0.title.lowercased().contains(needle) }
        return MangasPage(mangas: filtered, hasNextPage: page < totalPages)
    }

    public func mangaDetails(_ manga: SManga) async throws -> SManga {
        var detailed = manga
        let seed = Self.seed(from: manga.url)
        detailed.author = "Author \(seed % 9 + 1)"
        detailed.artist = "Artist \(seed % 7 + 1)"
        detailed.description = "A generated sample manga used to exercise the Komikku iOS port. "
            + "It has \(chaptersPerManga) chapters of \(pagesPerChapter) pages each."
        detailed.genre = ["Action", "Drama", "Fantasy", "Comedy", "Slice of Life"][seed % 5] + ", Sample"
        detailed.status = seed % 2 == 0 ? .ongoing : .completed
        detailed.initialized = true
        return detailed
    }

    public func chapterList(_ manga: SManga) async throws -> [SChapter] {
        let seed = Self.seed(from: manga.url)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        // Sources return newest first (Komikku's convention).
        return (1...chaptersPerManga).reversed().map { number in
            SChapter(
                name: "Chapter \(number)",
                url: "\(manga.url)/chapter-\(number)",
                dateUpload: now - Int64(chaptersPerManga - number) * 7 * 24 * 3_600_000 - Int64(seed),
                chapterNumber: Double(number),
                scanlator: "Sample Scans"
            )
        }
    }

    public func pageList(_ chapter: SChapter) async throws -> [SPage] {
        let seed = Self.seed(from: chapter.url)
        return (0..<pagesPerChapter).map { index in
            SPage(index: index, url: "\(chapter.url)/\(index + 1)", imageURL: "sample://\(seed)/\(index + 1)")
        }
    }

    // MARK: - Helpers

    private func makePage(page: Int, offset: Int) -> MangasPage {
        let start = (page - 1) * pageSize
        let mangas = (0..<pageSize).map { i -> SManga in
            let n = offset + start + i + 1
            return SManga(url: "/manga/\(n)", title: "Sample Manga \(n)")
        }
        return MangasPage(mangas: mangas, hasNextPage: page < totalPages)
    }

    /// Stable, process-independent hash (Swift's `hashValue` is randomised per launch).
    static func seed(from string: String) -> Int {
        string.utf8.reduce(5381) { ($0 &* 33 &+ Int($1)) & 0x7fffffff }
    }
}
