import SwiftUI

struct MoreView: View {
    @AppStorage("defaultReaderMode") private var defaultReaderMode = ReaderMode.rightToLeft.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section("Reader") {
                    Picker("Default reading mode", selection: $defaultReaderMode) {
                        ForEach(ReaderMode.allCases.filter { $0 != .defaultMode }) {
                            Text($0.title).tag($0.rawValue)
                        }
                    }
                }
                Section("About") {
                    LabeledContent("App", value: "Komikku for iOS (unofficial port)")
                    Link("Original Komikku (Android)", destination: URL(string: "https://github.com/komikku-app/komikku")!)
                }
            }
            .navigationTitle("More")
        }
    }
}
