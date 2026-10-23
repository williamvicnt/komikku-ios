import Foundation

/// Port of `Page`: one reader page returned by a source.
///
/// Like Komikku, a page may first only have `url` (a page that must be resolved with
/// `Source.imageURL(for:)`) and later an `imageURL` pointing at the actual image.
public struct SPage: Codable, Hashable, Sendable, Identifiable {
    public var index: Int
    public var url: String
    public var imageURL: String?

    public var id: Int { index }
    /// 1-based page number.
    public var number: Int { index + 1 }

    public init(index: Int, url: String = "", imageURL: String? = nil) {
        self.index = index
        self.url = url
        self.imageURL = imageURL
    }
}

/// Port of `MangasPage`.
public struct MangasPage: Sendable {
    public var mangas: [SManga]
    public var hasNextPage: Bool

    public init(mangas: [SManga], hasNextPage: Bool) {
        self.mangas = mangas
        self.hasNextPage = hasNextPage
    }
}
