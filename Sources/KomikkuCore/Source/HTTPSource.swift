import Foundation

/// Port of `HttpSource`: base class for sources backed by a website or API.
///
/// Subclass it and override the `...Request` / `...Parse` pairs, exactly like a Komikku
/// extension. Parsing receives raw `Data` so each source can pick JSON, HTML
/// (e.g. with SwiftSoup) or anything else without this package depending on a parser.
///
/// `@unchecked Sendable`: subclasses must keep their stored properties immutable.
open class HTTPSource: Source, @unchecked Sendable {
    public let name: String
    public let lang: String
    public let baseURL: URL
    public let versionID: Int
    public let session: URLSession

    public init(
        name: String,
        lang: String,
        baseURL: URL,
        versionID: Int = 1,
        session: URLSession = .shared
    ) {
        self.name = name
        self.lang = lang
        self.baseURL = baseURL
        self.versionID = versionID
        self.session = session
    }

    public var id: Int64 { SourceID.make(name: name, lang: lang, versionID: versionID) }
    open var supportsLatest: Bool { false }
    open func filterList() -> FilterList { [] }

    /// Headers added to every request. Override to customise (port of `headersBuilder`).
    open var headers: [String: String] {
        ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"]
    }

    public func makeRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return request
    }

    /// Executes a request and validates the HTTP status (port of `client.newCall(...).awaitSuccess()`).
    public func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SourceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw SourceError.httpStatus(http.statusCode) }
        return (data, http)
    }

    // MARK: - Override points

    open func popularMangaRequest(page: Int) throws -> URLRequest {
        throw SourceError.notImplemented("popularMangaRequest")
    }
    open func popularMangaParse(_ data: Data, response: HTTPURLResponse) throws -> MangasPage {
        throw SourceError.notImplemented("popularMangaParse")
    }

    open func latestUpdatesRequest(page: Int) throws -> URLRequest {
        throw SourceError.notImplemented("latestUpdatesRequest")
    }
    open func latestUpdatesParse(_ data: Data, response: HTTPURLResponse) throws -> MangasPage {
        throw SourceError.notImplemented("latestUpdatesParse")
    }

    open func searchMangaRequest(page: Int, query: String, filters: FilterList) throws -> URLRequest {
        throw SourceError.notImplemented("searchMangaRequest")
    }
    open func searchMangaParse(_ data: Data, response: HTTPURLResponse) throws -> MangasPage {
        throw SourceError.notImplemented("searchMangaParse")
    }

    open func mangaDetailsRequest(_ manga: SManga) throws -> URLRequest {
        makeRequest(try absoluteURL(manga.url))
    }
    open func mangaDetailsParse(_ data: Data, response: HTTPURLResponse) throws -> SManga {
        throw SourceError.notImplemented("mangaDetailsParse")
    }

    open func chapterListRequest(_ manga: SManga) throws -> URLRequest {
        makeRequest(try absoluteURL(manga.url))
    }
    open func chapterListParse(_ data: Data, response: HTTPURLResponse) throws -> [SChapter] {
        throw SourceError.notImplemented("chapterListParse")
    }

    open func pageListRequest(_ chapter: SChapter) throws -> URLRequest {
        makeRequest(try absoluteURL(chapter.url))
    }
    open func pageListParse(_ data: Data, response: HTTPURLResponse) throws -> [SPage] {
        throw SourceError.notImplemented("pageListParse")
    }

    open func imageURLRequest(for page: SPage) throws -> URLRequest {
        makeRequest(try absoluteURL(page.url))
    }
    open func imageURLParse(_ data: Data, response: HTTPURLResponse) throws -> String {
        throw SourceError.notImplemented("imageURLParse")
    }

    /// Resolves a source-relative path against `baseURL` (Komikku stores relative URLs).
    public func absoluteURL(_ path: String) throws -> URL {
        if let url = URL(string: path), url.scheme != nil { return url }
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw SourceError.parsing("invalid URL: \(path)")
        }
        return url
    }

    // MARK: - Source

    public func popularManga(page: Int) async throws -> MangasPage {
        let (data, response) = try await fetch(try popularMangaRequest(page: page))
        return try popularMangaParse(data, response: response)
    }

    public func latestUpdates(page: Int) async throws -> MangasPage {
        let (data, response) = try await fetch(try latestUpdatesRequest(page: page))
        return try latestUpdatesParse(data, response: response)
    }

    public func searchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage {
        let (data, response) = try await fetch(try searchMangaRequest(page: page, query: query, filters: filters))
        return try searchMangaParse(data, response: response)
    }

    public func mangaDetails(_ manga: SManga) async throws -> SManga {
        let (data, response) = try await fetch(try mangaDetailsRequest(manga))
        return try mangaDetailsParse(data, response: response)
    }

    public func chapterList(_ manga: SManga) async throws -> [SChapter] {
        let (data, response) = try await fetch(try chapterListRequest(manga))
        return try chapterListParse(data, response: response)
    }

    public func pageList(_ chapter: SChapter) async throws -> [SPage] {
        let (data, response) = try await fetch(try pageListRequest(chapter))
        return try pageListParse(data, response: response)
    }

    public func imageURL(for page: SPage) async throws -> String {
        if let url = page.imageURL { return url }
        let (data, response) = try await fetch(try imageURLRequest(for: page))
        return try imageURLParse(data, response: response)
    }
}
