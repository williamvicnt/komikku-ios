import Foundation

public enum TriState: Int, Codable, Sendable {
    case ignore = 0
    case include = 1
    case exclude = 2
}

public struct SortSelection: Codable, Hashable, Sendable {
    public var index: Int
    public var ascending: Bool

    public init(index: Int, ascending: Bool) {
        self.index = index
        self.ascending = ascending
    }
}

/// Port of Komikku's `Filter<T>` hierarchy as a value-type enum.
/// Mutating a filter means replacing it in the `FilterList` (UI binds to the array).
public indirect enum SourceFilter: Codable, Hashable, Sendable {
    case header(name: String)
    case separator
    case select(name: String, values: [String], state: Int)
    case text(name: String, state: String)
    case checkBox(name: String, state: Bool)
    case triState(name: String, state: TriState)
    case group(name: String, filters: [SourceFilter])
    case sort(name: String, values: [String], state: SortSelection?)

    public var name: String {
        switch self {
        case .header(let name), .select(let name, _, _), .text(let name, _),
             .checkBox(let name, _), .triState(let name, _), .group(let name, _),
             .sort(let name, _, _):
            name
        case .separator:
            ""
        }
    }
}

public typealias FilterList = [SourceFilter]
