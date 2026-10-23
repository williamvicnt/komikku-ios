import SwiftUI
import KomikkuCore

/// Generic renderer for a source's `FilterList` (port of Komikku's `SourceFilterDialog`).
/// Works for any source because filters are plain data (`SourceFilter`).
struct FiltersSheet: View {
    @Binding var filters: FilterList
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                ForEach(filters.indices, id: \.self) { index in
                    FilterRow(filter: Binding(
                        get: { filters[index] },
                        set: { filters[index] = $0 }
                    ))
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Apply", action: onApply) }
            }
        }
    }
}

struct FilterRow: View {
    @Binding var filter: SourceFilter

    var body: some View {
        switch filter {
        case .header(let name):
            Text(name).font(.footnote).foregroundStyle(.secondary)

        case .separator:
            Divider()

        case .select(let name, let values, let state):
            Picker(name, selection: Binding(
                get: { state },
                set: { filter = .select(name: name, values: values, state: $0) }
            )) {
                ForEach(values.indices, id: \.self) { Text(values[$0]).tag($0) }
            }

        case .text(let name, let state):
            TextField(name, text: Binding(
                get: { state },
                set: { filter = .text(name: name, state: $0) }
            ))

        case .checkBox(let name, let state):
            Toggle(name, isOn: Binding(
                get: { state },
                set: { filter = .checkBox(name: name, state: $0) }
            ))

        case .triState(let name, let state):
            Button {
                let next: TriState = switch state {
                case .ignore: .include
                case .include: .exclude
                case .exclude: .ignore
                }
                filter = .triState(name: name, state: next)
            } label: {
                HStack {
                    Text(name).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: icon(for: state)).foregroundStyle(.tint)
                }
            }

        case .group(let name, let children):
            DisclosureGroup(name) {
                ForEach(children.indices, id: \.self) { index in
                    FilterRow(filter: Binding(
                        get: { children[index] },
                        set: { newValue in
                            var copy = children
                            copy[index] = newValue
                            filter = .group(name: name, filters: copy)
                        }
                    ))
                }
            }

        case .sort(let name, let values, let state):
            VStack(alignment: .leading) {
                Picker(name, selection: Binding(
                    get: { state?.index ?? 0 },
                    set: { filter = .sort(name: name, values: values,
                                          state: SortSelection(index: $0, ascending: state?.ascending ?? false)) }
                )) {
                    ForEach(values.indices, id: \.self) { Text(values[$0]).tag($0) }
                }
                Toggle("Ascending", isOn: Binding(
                    get: { state?.ascending ?? false },
                    set: { filter = .sort(name: name, values: values,
                                          state: SortSelection(index: state?.index ?? 0, ascending: $0)) }
                ))
            }
        }
    }

    private func icon(for state: TriState) -> String {
        switch state {
        case .ignore: "square"
        case .include: "checkmark.square.fill"
        case .exclude: "xmark.square.fill"
        }
    }
}
