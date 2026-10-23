import SwiftUI
import SwiftData
import KomikkuCore

/// Reader port: paged (LTR/RTL), vertical paging and webtoon modes, progress + history.
struct ReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.sourceManager) private var sources
    @AppStorage("defaultReaderMode") private var defaultReaderMode = ReaderMode.rightToLeft.rawValue

    @State private var chapter: ChapterEntity
    @State private var pages: [SPage] = []
    @State private var current = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showChrome = true
    @State private var openedAt = Date()

    init(chapter: ChapterEntity) {
        _chapter = State(initialValue: chapter)
    }

    private var manga: MangaEntity? { chapter.manga }
    private var source: (any Source)? { manga.flatMap { sources.source(id: $0.source) } }

    private var mode: ReaderMode {
        let perManga = ReaderMode(rawValue: manga?.viewer ?? 0) ?? .defaultMode
        return perManga == .defaultMode ? (ReaderMode(rawValue: defaultReaderMode) ?? .rightToLeft) : perManga
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
                .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { showChrome.toggle() } }
            if showChrome { chrome }
        }
        .statusBarHidden(!showChrome)
        .task(id: chapter.persistentModelID) { await loadPages() }
        .onChange(of: current) { saveProgress() }
        .onDisappear { finishSession() }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if isLoading {
            ProgressView().tint(.white)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage).foregroundStyle(.white).multilineTextAlignment(.center)
                Button("Retry") { Task { await loadPages() } }.buttonStyle(.bordered)
            }
            .padding()
        } else if pages.isEmpty {
            Text("This chapter has no pages").foregroundStyle(.white)
        } else {
            switch mode {
            case .leftToRight, .rightToLeft, .defaultMode:
                pagedReader(rtl: mode != .leftToRight)
            case .vertical:
                verticalPagedReader
            case .webtoon:
                webtoonReader
            }
        }
    }

    private func pagedReader(rtl: Bool) -> some View {
        TabView(selection: $current) {
            ForEach(pages) { page in
                PageImageView(page: page, source: source)
                    .environment(\.layoutDirection, .leftToRight)
                    .tag(page.index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // A right-to-left layout direction flips the swipe direction of the paged TabView.
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
        .ignoresSafeArea()
    }

    private var verticalPagedReader: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(pages) { page in
                    PageImageView(page: page, source: source)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(page.index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: Binding(get: { current as Int? }, set: { newValue in if let newValue { current = newValue } }))
        .ignoresSafeArea()
    }

    private var webtoonReader: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(pages) { page in
                    PageImageView(page: page, source: source)
                        .onAppear { current = page.index }
                }
            }
        }
        .ignoresSafeArea(edges: .horizontal)
    }

    // MARK: Chrome

    private var chrome: some View {
        VStack {
            HStack {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                VStack(alignment: .leading) {
                    Text(manga?.title ?? "").font(.subheadline.bold()).lineLimit(1)
                    Text(chapter.name).font(.caption).lineLimit(1)
                }
                Spacer()
                Menu {
                    Picker("Reader mode", selection: Binding(
                        get: { manga?.viewer ?? 0 },
                        set: { manga?.viewer = $0; try? context.save() }
                    )) {
                        ForEach(ReaderMode.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                } label: {
                    Image(systemName: "rectangle.on.rectangle.angled")
                }
            }
            .padding()
            .background(.black.opacity(0.7))

            Spacer()

            VStack(spacing: 8) {
                if pages.count > 1 {
                    Slider(
                        value: Binding(get: { Double(current) }, set: { current = Int($0.rounded()) }),
                        in: 0...Double(pages.count - 1), step: 1
                    )
                }
                HStack {
                    Button("Previous", systemImage: "chevron.left") { move(by: +1) }
                        .disabled(adjacentChapter(by: +1) == nil)
                    Spacer()
                    Text("\(min(current + 1, max(pages.count, 1))) / \(pages.count)")
                        .font(.footnote.monospacedDigit())
                    Spacer()
                    Button("Next", systemImage: "chevron.right") { move(by: -1) }
                        .labelStyle(.titleAndIcon)
                        .disabled(adjacentChapter(by: -1) == nil)
                }
            }
            .padding()
            .background(.black.opacity(0.7))
        }
        .foregroundStyle(.white)
        .tint(.white)
    }

    // MARK: Data

    private func loadPages() async {
        guard let source else {
            isLoading = false
            errorMessage = "This source is not installed."
            return
        }
        isLoading = true
        errorMessage = nil
        openedAt = Date()
        do {
            pages = try await source.pageList(chapter.asSChapter)
            // Resume where the user stopped, unless the chapter was already finished.
            current = chapter.read ? 0 : min(chapter.lastPageRead, max(pages.count - 1, 0))
        } catch {
            pages = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func saveProgress() {
        guard !pages.isEmpty else { return }
        let finished = current >= pages.count - 1
        LibraryRepository(context: context).saveProgress(chapter, page: current, finished: finished)
    }

    /// Records elapsed time in history when the reader closes or changes chapter.
    private func finishSession() {
        let elapsed = Int64(Date().timeIntervalSince(openedAt) * 1000)
        guard !pages.isEmpty else { return }
        LibraryRepository(context: context).recordHistory(for: chapter, readMillis: elapsed)
    }

    /// `offset` +1 = older chapter, -1 = newer (source order is newest first).
    private func adjacentChapter(by offset: Int) -> ChapterEntity? {
        guard let chapters = manga?.chapters.sorted(by: { $0.sourceOrder < $1.sourceOrder }),
              let index = chapters.firstIndex(where: { $0.persistentModelID == chapter.persistentModelID })
        else { return nil }
        let target = index + offset
        return chapters.indices.contains(target) ? chapters[target] : nil
    }

    private func move(by offset: Int) {
        guard let target = adjacentChapter(by: offset) else { return }
        finishSession()
        pages = []
        chapter = target
    }
}
