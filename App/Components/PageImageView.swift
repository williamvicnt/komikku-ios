import SwiftUI
import KomikkuCore

/// Reader page. Resolves `page.url` → image URL lazily (like Komikku's page loader) and
/// renders the demo `sample://` scheme without any network.
struct PageImageView: View {
    let page: SPage
    let source: (any Source)?

    @State private var resolved: URL?
    @State private var failed = false

    var body: some View {
        Group {
            if let raw = page.imageURL, raw.hasPrefix("sample://") {
                SamplePageView(descriptor: raw)
            } else if let resolved {
                AsyncImage(url: resolved) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        failureView
                    default:
                        ProgressView().tint(.white)
                    }
                }
            } else if failed {
                failureView
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .task(id: page.id) { await resolve() }
    }

    private var failureView: some View {
        Label("Page \(page.number) failed to load", systemImage: "exclamationmark.triangle")
            .foregroundStyle(.white.opacity(0.7))
            .padding()
    }

    private func resolve() async {
        if let raw = page.imageURL, raw.hasPrefix("sample://") { return }
        if let raw = page.imageURL, let url = URL(string: raw) {
            resolved = url
            return
        }
        guard let source else { failed = true; return }
        do {
            let raw = try await source.imageURL(for: page)
            if let url = URL(string: raw) { resolved = url } else { failed = true }
        } catch {
            failed = true
        }
    }
}

/// Placeholder page for `sample://<seed>/<number>` URLs.
struct SamplePageView: View {
    let descriptor: String

    var body: some View {
        let url = URL(string: descriptor)
        let seed = Int(url?.host ?? "") ?? 0
        let number = url?.lastPathComponent ?? "?"
        let hue = Double(seed % 360) / 360
        Rectangle()
            .fill(Color(hue: hue, saturation: 0.35, brightness: 0.9))
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay(
                Text(number)
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.35))
            )
    }
}
