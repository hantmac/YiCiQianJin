import SwiftUI

// MARK: - Page chrome

/// System navigation bar for a page. Using the system toolbar (instead of a custom header) lets
/// iPhone Duo move Back/Close onto the vertical side bar of the outer display.
struct PageChrome: ViewModifier {
    let title: String
    let backLabel: String
    let onBack: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onBack) {
                        Label(backLabel, systemImage: backLabel == "关闭" ? "xmark" : "chevron.left")
                    }
                }
            }
    }
}

extension View {
    func pageChrome(_ title: String, backLabel: String = "返回", onBack: @escaping () -> Void) -> some View {
        modifier(PageChrome(title: title, backLabel: backLabel, onBack: onBack))
    }

    /// Keeps single-column content at a readable width on wide displays (iPhone Duo inner, iPad).
    func readableWidth(_ maxWidth: CGFloat = 640) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

// MARK: - Split layout

enum AdaptiveMetrics {
    /// Minimum container width for side-by-side panes. A layout parameter, not a device size.
    static let splitMinWidth: CGFloat = 600

    /// Side-by-side when the container is landscape-shaped and wide enough, or when a fold
    /// divides it (iPhone Duo partially open) so content isn't laid across the hinge.
    static func useSplit(size: CGSize, hasActiveDivision: Bool) -> Bool {
        hasActiveDivision || (size.width > size.height && size.width >= splitMinWidth)
    }
}

/// Chooses between a compact single-column layout and two panes, based on the space this view
/// actually gets (never on device model). On iOS 27.1+ the panes use `ArrangementView`, which
/// places them on either side of the iPhone Duo fold.
struct AdaptiveSplit<Primary: View, Secondary: View, Compact: View>: View {
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary
    @ViewBuilder var compact: () -> Compact

    @State private var split = false

    var body: some View {
        Group {
            if split {
                SplitPanes(primary: primary, secondary: secondary)
            } else {
                compact()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Measure without the keyboard: on iPad portrait the keyboard makes the container wider
        // than tall, and flipping layouts then would rebuild (and unfocus) the text field.
        .background {
            GeometryReader { proxy in
                let wantsSplit = AdaptiveMetrics.useSplit(size: proxy.size, hasActiveDivision: Self.hasActiveDivision(proxy))
                Color.clear
                    .onAppear { split = wantsSplit }
                    .onChange(of: wantsSplit) { _, new in split = new }
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    private static func hasActiveDivision(_ proxy: GeometryProxy) -> Bool {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division).contains(where: \.isActive)
        }
        return false
    }
}

struct SplitPanes<Primary: View, Secondary: View>: View {
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                primary()
            } secondary: {
                secondary()
            }
            .arrangementViewStyle(.split)
        } else {
            HStack(alignment: .top, spacing: 0) {
                primary().frame(maxWidth: .infinity)
                secondary().frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Illustration

/// Word Atlas illustration for a word; renders nothing when the word has no picture.
struct WordIllustration: View {
    let word: String
    var cornerRadius: CGFloat = 22
    /// Downsample target in pixels; nil keeps the full 512px original.
    var maxPixel: CGFloat? = nil

    @State private var image: UIImage?
    @State private var loaded = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Rectangle()
                    .fill(Theme.surface)
                    .overlay {
                        if !loaded { ProgressView().tint(.white.opacity(0.6)) }
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Theme.stroke))
        .accessibilityLabel("\(word) 的插画")
        .accessibilityAddTraits(.isImage)
        .task(id: word) {
            let result = await WordAtlas.image(for: word, maxPixel: maxPixel)
            withAnimation(.easeOut(duration: 0.25)) {
                image = result
                loaded = true
            }
        }
    }
}

/// Small square thumbnail for lists; empty placeholder keeps rows aligned when there's no picture.
struct WordThumbnail: View {
    let word: String
    var size: CGFloat = 52

    var body: some View {
        Group {
            if WordAtlas.hasImage(word) {
                WordIllustration(word: word, cornerRadius: 12, maxPixel: size * 3)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        Text(String(word.prefix(1)).uppercased())
                            .font(Theme.wordFont(size * 0.42))
                            .foregroundStyle(Theme.textTertiary)
                    )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Bilingual example sentences (with TTS) for a word.
struct ExampleSentences: View {
    let word: String
    let examples: [AtlasEntry.Example]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(index == 0 ? "日常例句" : "考试例句")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.gold)
                        Text(highlighted(example.en))
                            .font(.callout)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(example.zh)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button {
                        Pronouncer.shared.speak(example.en)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(Theme.surface, in: Circle())
                    }
                    .accessibilityLabel("朗读例句")
                }
            }
        }
    }

    /// Bolds the headword (and simple inflections) inside the sentence.
    private func highlighted(_ sentence: String) -> AttributedString {
        var text = AttributedString(sentence)
        let stem = word.lowercased()
        guard stem.count >= 3 else { return text }
        var searchStart = sentence.startIndex
        while let range = sentence.range(of: stem, options: .caseInsensitive, range: searchStart..<sentence.endIndex) {
            // Extend over trailing letters so "decided" highlights fully for "decide".
            var end = range.upperBound
            while end < sentence.endIndex, sentence[end].isLetter { end = sentence.index(after: end) }
            // Only match at a word start ("ear" must not light up inside "learn").
            let atWordStart = range.lowerBound == sentence.startIndex
                || !sentence[sentence.index(before: range.lowerBound)].isLetter
            if atWordStart,
               let lo = AttributedString.Index(range.lowerBound, within: text),
               let hi = AttributedString.Index(end, within: text) {
                text[lo..<hi].foregroundColor = Theme.gold
                text[lo..<hi].inlinePresentationIntent = .stronglyEmphasized
            }
            searchStart = end
        }
        return text
    }
}
