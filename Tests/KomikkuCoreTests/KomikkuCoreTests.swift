import XCTest
@testable import KomikkuCore

final class KomikkuCoreTests: XCTestCase {
    // MARK: SManga

    func testGenresAreSplitTrimmedAndDeduplicated() {
        let manga = SManga(url: "/a", title: "A", genre: "Action, Drama,  Action, , Fantasy")
        XCTAssertEqual(manga.genres, ["Action", "Drama", "Fantasy"])
    }

    func testGenresNilWhenBlank() {
        XCTAssertNil(SManga(url: "/a", title: "A", genre: "   ").genres)
        XCTAssertNil(SManga(url: "/a", title: "A", genre: nil).genres)
    }

    func testStatusRawValuesMatchKomikkuDatabase() {
        XCTAssertEqual(MangaStatus.ongoing.rawValue, 1)
        XCTAssertEqual(MangaStatus.completed.rawValue, 2)
        XCTAssertEqual(MangaStatus.onHiatus.rawValue, 6)
    }

    // MARK: SourceID

    func testSourceIDIsStableAndPositive() {
        let a = SourceID.make(name: "Sample Source", lang: "en")
        let b = SourceID.make(name: "sample source", lang: "en") // name is lowercased
        XCTAssertEqual(a, b)
        XCTAssertGreaterThan(a, 0)
        XCTAssertNotEqual(a, SourceID.make(name: "Sample Source", lang: "pt"))
        XCTAssertNotEqual(a, SourceID.make(name: "Sample Source", lang: "en", versionID: 2))
    }

    #if canImport(CryptoKit)
    /// Known Komikku/Tachiyomi value: MangaDex ("mangadex/en/1") has id 2499283573021220255.
    func testSourceIDMatchesKnownTachiyomiID() {
        XCTAssertEqual(SourceID.make(name: "MangaDex", lang: "en"), 2_499_283_573_021_220_255)
    }
    #endif

    // MARK: SourceManager

    func testSourceManagerRegistersAndSorts() {
        let manager = SourceManager(sources: [SampleSource()])
        XCTAssertNotNil(manager.source(id: SampleSource.sourceID))
        XCTAssertEqual(manager.allSources.count, 1)
        manager.unregister(id: SampleSource.sourceID)
        XCTAssertNil(manager.source(id: SampleSource.sourceID))
    }

    // MARK: SampleSource

    func testSamplePopularPaging() async throws {
        let source = SampleSource()
        let first = try await source.popularManga(page: 1)
        XCTAssertEqual(first.mangas.count, 20)
        XCTAssertTrue(first.hasNextPage)
        let last = try await source.popularManga(page: 3)
        XCTAssertFalse(last.hasNextPage)
        XCTAssertNotEqual(first.mangas.first?.url, last.mangas.first?.url)
    }

    func testSampleSearchFilters() async throws {
        let result = try await SampleSource().searchManga(page: 1, query: "manga 7", filters: [])
        XCTAssertEqual(result.mangas.map(\.title), ["Sample Manga 7"])
    }

    func testSampleChaptersNewestFirstAndPagesIndexed() async throws {
        let source = SampleSource()
        let manga = SManga(url: "/manga/1", title: "Sample Manga 1")
        let chapters = try await source.chapterList(manga)
        XCTAssertEqual(chapters.count, 12)
        XCTAssertEqual(chapters.first?.chapterNumber, 12)
        XCTAssertEqual(chapters.last?.chapterNumber, 1)

        let pages = try await source.pageList(chapters[0])
        XCTAssertEqual(pages.map(\.number), Array(1...10))
        XCTAssertNotNil(pages.first?.imageURL)
    }

    func testMangaUpdateFetchesOnlyWhatIsRequested() async throws {
        let source = SampleSource()
        let manga = SManga(url: "/manga/2", title: "Sample Manga 2")
        let update = try await source.mangaUpdate(manga: manga, chapters: [], fetchDetails: false, fetchChapters: true)
        XCTAssertFalse(update.manga.initialized)
        XCTAssertEqual(update.chapters.count, 12)

        let detailsOnly = try await source.mangaUpdate(manga: manga, chapters: [], fetchDetails: true, fetchChapters: false)
        XCTAssertTrue(detailsOnly.manga.initialized)
        XCTAssertTrue(detailsOnly.chapters.isEmpty)
    }

    // MARK: HTTPSource

    func testAbsoluteURLResolution() throws {
        let source = HTTPSource(name: "T", lang: "en", baseURL: URL(string: "https://example.com")!)
        XCTAssertEqual(try source.absoluteURL("/manga/1").absoluteString, "https://example.com/manga/1")
        XCTAssertEqual(try source.absoluteURL("https://cdn.example.org/a.png").absoluteString, "https://cdn.example.org/a.png")
    }

    func testUnimplementedHTTPSourceThrows() async {
        let source = HTTPSource(name: "T", lang: "en", baseURL: URL(string: "https://example.com")!)
        do {
            _ = try await source.popularManga(page: 1)
            XCTFail("expected notImplemented")
        } catch SourceError.notImplemented {
            // expected
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}
