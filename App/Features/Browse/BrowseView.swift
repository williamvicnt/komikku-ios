import SwiftUI
import KomikkuCore

struct BrowseView: View {
    @Environment(\.sourceManager) private var sources

    var body: some View {
        NavigationStack {
            List {
                ForEach(sources.languages, id: \.self) { language in
                    Section(language.isEmpty ? "Other" : language.uppercased()) {
                        ForEach(sources.allSources.filter { $0.lang == language }, id: \.id) { source in
                            NavigationLink(value: SourceRoute(sourceID: source.id)) {
                                VStack(alignment: .leading) {
                                    Text(source.name)
                                    if source.supportsLatest {
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
