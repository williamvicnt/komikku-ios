import SwiftUI
import KomikkuCore

/// Cover with a deterministic gradient fallback (sources may not provide thumbnails).
struct CoverImage: View {
    let urlString: String?
    let title: String

    var body: some View {
        ZStack {
            placeholder
            if let urlString, let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        let hue = Double(abs(title.hashValueStable) % 360) / 360
        return LinearGradient(
            colors: [Color(hue: hue, saturation: 0.5, brightness: 0.75),
                     Color(hue: hue, saturation: 0.7, brightness: 0.45)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(6)
                .lineLimit(4)
        )
    }
}

private extension String {
    /// `hashValue` changes every launch; use a stable hash so covers keep their colour.
    var hashValueStable: Int {
        utf8.reduce(5381) { ($0 &* 33 &+ Int($1)) & 0x7fffffff }
    }
}

struct MangaGridCell: View {
    let urlString: String?
    let title: String
    var badge: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CoverImage(urlString: urlString, title: title)
                .overlay(alignment: .topLeading) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.tint, in: Capsule())
                            .foregroundStyle(.white)
                            .padding(4)
                    }
                }
            Text(title)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }
}

let mangaGridColumns = [GridItem(.adaptive(minimum: 105, maximum: 160), spacing: 10, alignment: .top)]
