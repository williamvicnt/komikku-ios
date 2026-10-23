import Foundation

/// Port of `SManga.ONGOING`, `COMPLETED`, ... (raw values match Komikku's database).
public enum MangaStatus: Int, Codable, Sendable, CaseIterable {
    case unknown = 0
    case ongoing = 1
    case completed = 2
    case licensed = 3
    case publishingFinished = 4
    case cancelled = 5
    case onHiatus = 6

    public var title: String {
        switch self {
        case .unknown: "Unknown"
        case .ongoing: "Ongoing"
        case .completed: "Completed"
        case .licensed: "Licensed"
        case .publishingFinished: "Publishing finished"
        case .cancelled: "Cancelled"
        case .onHiatus: "On hiatus"
        }
    }
}

/// Port of `UpdateStrategy` (ALWAYS_UPDATE = 0, ONLY_FETCH_ONCE = 1).
public enum UpdateStrategy: Int, Codable, Sendable {
    case alwaysUpdate = 0
    case onlyFetchOnce = 1
}

/// Port of `SManga`: what a source returns about a manga.
public struct SManga: Codable, Hashable, Sendable {
    public var url: String
    public var title: String
    public var thumbnailURL: String?
    public var artist: String?
    public var author: String?
    public var description: String?
    /// Comma separated, like Komikku (`"Action, Drama"`).
    public var genre: String?
    public var status: MangaStatus
    public var updateStrategy: UpdateStrategy
    public var initialized: Bool

    public init(
        url: String,
        title: String,
        artist: String? = nil,
        author: String? = nil,
        description: String? = nil,
        genre: String? = nil,
        status: MangaStatus = .unknown,
        thumbnailURL: String? = nil,
        updateStrategy: UpdateStrategy = .alwaysUpdate,
        initialized: Bool = false
    ) {
        self.url = url
        self.title = title
        self.artist = artist
        self.author = author
        self.description = description
        self.genre = genre
        self.status = status
        self.thumbnailURL = thumbnailURL
        self.updateStrategy = updateStrategy
        self.initialized = initialized
    }

    /// Port of `SManga.getGenres()`: split on ", ", trim, drop blanks, de-duplicate keeping order.
    public var genres: [String]? {
        guard let genre, !genre.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var seen = Set<String>()
        return genre
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
