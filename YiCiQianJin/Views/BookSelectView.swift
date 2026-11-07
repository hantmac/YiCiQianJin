import SwiftUI

struct BookSelectView: View {
    @Bindable var vm: StudyViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isFirstLaunch: Bool { vm.state.selectedBookId == nil }

    var body: some View {
        let content = VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isFirstLaunch {
                        VStack(alignment: .leading, spacing: 8) {
                            Mascot(size: 96)
                            Text("小象单词")
                                .font(.largeTitle.bold())
                                .foregroundStyle(Theme.textPrimary)
                            Text("你好，我是小象！每天陪你记一个词，配一幅画，第二天考考你。\n先选一本适合你的词书吧。")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    } else {
                        Text("切换词书不会丢失进度，随时可以换回来")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 8)
                    }

                    // Even column count on wide displays so the iPhone Duo fold falls between cards.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                             count: sizeClass == .regular ? 2 : 1), spacing: 12) {
                        ForEach(WordData.books) { book in
                            bookRow(book)
                        }
                    }
                }
                .padding()
                .readableWidth(900)
            }
            .scrollIndicators(.hidden)
        }
        if isFirstLaunch {
            content
        } else {
            content.pageChrome("选择词书") { vm.go(.home) }
        }
    }

    private func bookRow(_ book: WordBook) -> some View {
        let learned = min(vm.progress(for: book.id), book.words.count)
        let progress = Double(learned) / Double(max(book.words.count, 1))
        let isCurrent = book.id == vm.state.selectedBookId

        return Button {
            vm.selectBook(book.id)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: book.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(book.tint)
                    .frame(width: 56, height: 56)
                    .background(book.tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(book.name)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        if isCurrent {
                            Text("学习中")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.onGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Theme.goldGradient, in: Capsule())
                        }
                    }
                    Text(learned > 0 ? "已学 \(learned) / \(book.words.count) 词" : "共 \(book.words.count) 词")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    if learned > 0 {
                        CapsuleBar(progress: progress, height: 5, tint: AnyShapeStyle(book.tint))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .card(padding: 14, fill: isCurrent ? Theme.surfaceStrong : Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(isCurrent ? Theme.gold.opacity(0.6) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(book.name)，\(learned > 0 ? "已学 \(learned) 词" : "共 \(book.words.count) 词")\(isCurrent ? "，学习中" : "")")
    }
}
