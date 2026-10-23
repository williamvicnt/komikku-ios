import SwiftUI
import KomikkuCore

private struct SourceItem: Identifiable {
    let source: any Source
    var id: Int64 { source.id }
}

struct BrowseView: View {
    @Environment(\.sourceManager) private var sources

    var body: some View {
        NavigationStack {
            List {
                ForEach(sources.languages, id: \.self) { language in
                    Section(language.isEmpty ? "Other" : language.uppercased()) {
                        ForEach(sources.allSources.filter { $0.lang == language }.map(SourceItem.init)) { item in
                            NavigationLink(value: SourceRoute(sourceID: item.source.id)) {
                                VStack(alignment: .leading) {
                                    Text(item.source.name)
                                    if item.source.supportsLatest {
                                        Text("Latest available").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if sources.allSources.isEmpty {
                    ContentUnavailableView("No sources", systemImage: "globe",
                                           description: Text("Register a Source in KomikkuApp.swift."))
                }
            }
            .navigationTitle("Browse")
            .navigationDestination(for: SourceRoute.self) { SourceCatalogView(sourceID: $0.sourceID) }
            .mangaDestination()
        }
    }
}
