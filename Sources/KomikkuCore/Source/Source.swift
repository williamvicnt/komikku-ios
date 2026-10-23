import Foundation

public enum SourceError: Error, LocalizedError, Sendable {
    case notImplemented(String)
    case httpStatus(Int)
    case invalidResponse
    case parsing(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented(let what): "Not supported by this source: \(what)"
        case .httpStatus(let code): "HTTP error \(code)"
        case .invalidResponse: "Invalid response from source"
        case .parsing(let message): "Could not parse source response: \(message)"
        }
    }
}

/// Port of Komikku's `Source` + `CatalogueSource` contract (suspend API), as async Swift.
///
/// iOS cannot load third-party code at runtime, so every source is compiled into the app
/// (or into a Swift package the app links). Implement this protocol to add a source.
public protocol Source: Sendable {
    var id: Int64 { get }
    var name: String { get }
    /// ISO 639-1 language code ("" / "all" for multi-language).
    var lang: String { get }
    var supportsLatest: Bool { get }

    func filterList() -> FilterList

    func popularManga(page: Int) async throws -> MangasPage
    func latestUpdates(page: Int) async throws -> MangasPage
    func searchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage

    func mangaDetails(_ manga: SManga) async throws -> SManga
    func chapterList(_ manga: SManga) async throws -> [SChapter]
    func pageList(_ chapter: SChapter) async throws -> [SPage]

    /// Resolve a page that only has `url` into its image URL (optional step).
    func imageURL(for page: SPage) async throws -> String
}

public extension Source {
    var lang: String { "" }
    var supportsLatest: Bool { false }
    func filterList() -> FilterList { [] }

    func latestUpdates(page: Int) async throws -> MangasPage {
        throw SourceError.notImplemented("latest updates")
    }

    func imageURL(for page: SPage) async throws -> String {
        guard let url = page.imageURL else { throw SourceError.notImplemented("image URL resolution") }
        return url
    }

    /// Port of `getMangaUpdate`: fetch details and/or chapters concurrently.
    func mangaUpdate(
        manga: SManga,
        chapters: [SChapter],
        fetchDetails: Bool,
        fetchChapters: Bool
    ) async throws -> SMangaUpdate {
        async let details = detailsIfNeeded(manga, fetch: fetchDetails)
        async let list = chaptersIfNeeded(manga, current: chapters, fetch: fetchChapters)
        return try await SMangaUpdate(manga: details, chapters: list)
    }

    private func detailsIfNeeded(_ manga: SManga, fetch: Bool) async throws -> SManga {
        if fetch { return try await mangaDetails(manga) }
        return manga
    }

    private func chaptersIfNeeded(_ manga: SManga, current: [SChapter], fetch: Bool) async throws -> [SChapter] {
        if fetch { return try await chapterList(manga) }
        return current
    }
}
