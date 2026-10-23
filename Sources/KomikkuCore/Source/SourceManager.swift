import Foundation

/// Port of `SourceManager`: registry of every installed source.
///
/// On Android sources come from extension APKs; here they are registered at app launch.
public final class SourceManager: @unchecked Sendable {
    private let lock = NSLock()
    private var sources: [Int64: any Source] = [:]

    public init(sources: [any Source] = []) {
        sources.forEach { register($0) }
    }

    public func register(_ source: any Source) {
        lock.lock(); defer { lock.unlock() }
        sources[source.id] = source
    }

    public func unregister(id: Int64) {
        lock.lock(); defer { lock.unlock() }
        sources[id] = nil
    }

    public func source(id: Int64) -> (any Source)? {
        lock.lock(); defer { lock.unlock() }
        return sources[id]
    }

    /// All sources sorted by language then name (the order Komikku shows in Browse).
    public var allSources: [any Source] {
        lock.lock(); defer { lock.unlock() }
        return sources.values.sorted {
            ($0.lang, $0.name.lowercased()) < ($1.lang, $1.name.lowercased())
        }
    }

    public var languages: [String] {
        Array(Set(allSources.map(\.lang))).sorted()
    }
}
