import SwiftUI

/// 插画图鉴: one illustrated card per learned word. Cards turn silver once the word survives
/// the first day-long review and gold when it is mastered.
struct CollectionView: View {
    @Bindable var vm: StudyViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var filter: Filter = .all
    @State private var selected: StudyRecord?

    enum Filter: String, CaseIterable, Identifiable {
        case all = "全部"
        case gold = "金卡"
        case silver = "银卡"
        case plain = "新卡"
        var id: String { rawValue }
    }

    enum Tier {
        case plain, silver, gold

        /// Passed the first day-long review.
        static let silverStage = SpacedRepetition.firstDayStage + 1

        init(stage: Int) {
            if stage >= SpacedRepetition.masteredStage {
                self = .gold
            } else if stage >= Self.silverStage {
                self = .silver
            } else {
                self = .plain
            }
        }

        var title: String {
            switch self {
            case .plain: return "新卡"
            case .silver: return "银卡"
            case .gold: return "金卡"
            }
        }

        var color: Color {
            switch self {
            case .plain: return Theme.textTertiary
            case .silver: return Theme.silver
            case .gold: return Theme.gold
            }
        }
    }

    private struct Card: Identifiable {
        let record: StudyRecord
        let tier: Tier
        let stage: Int
        var id: String { record.wordKey }
    }

    private var cards: [Card] {
        vm.learnedWords.reversed()
            .filter { WordAtlas.hasImage($0.word) }
            .map { record in
                let stage = vm.reviewState(for: record).stage
                return Card(record: record, tier: Tier(stage: stage), stage: stage)
            }
    }

    var body: some View {
        let all = cards
        let shown = all.filter { card in
            switch filter {
            case .all: return true
            case .gold: return card.tier == .gold
            case .silver: return card.tier == .silver
            case .plain: return card.tier == .plain
            }
        }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 5 : 3)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(all)
                filterBar(all)
                if all.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        if filter == .all { nextCardTeaser }
                        ForEach(shown) { cardView($0) }
                    }
                    if shown.isEmpty {
                        Text(emptyFilterText)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
            }
            .padding()
            .readableWidth(900)
        }
        .scrollIndicators(.hidden)
        .pageChrome("插画图鉴") { vm.go(.home) }
        .sheet(item: $selected) { record in
            CollectionCardSheet(vm: vm, record: record)
        }
    }

    // MARK: - Header

    private func header(_ all: [Card]) -> some View {
        let gold = all.filter { $0.tier == .gold }.count
        let silver = all.filter { $0.tier == .silver }.count
        let total = (vm.currentBook?.words ?? []).filter { WordAtlas.hasImage($0.word) }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(all.count)")
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                Text("张插画卡")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            HStack(spacing: 14) {
                tierCount(.gold, gold)
                tierCount(.silver, silver)
                tierCount(.plain, all.count - gold - silver)
            }
            if total > 0, let book = vm.currentBook {
                Text("「\(book.name)」共有 \(total) 张插画等你收集。每学一个词得到一张新卡，按时复习让它升级：坚持过 1 天复习成为银卡，掌握后成为金卡。")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tierCount(_ tier: Tier, _ count: Int) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tier.color)
                .frame(width: 8, height: 11)
            Text("\(tier.title) \(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func filterBar(_ all: [Card]) -> some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { item in
                Button { filter = item } label: {
                    Text(item.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(filter == item ? Theme.onGold : Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(filter == item ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surface), in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(filter == item ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }

    private var emptyFilterText: String {
        switch filter {
        case .gold: return "还没有金卡。单词通过 7 天复习后，卡片会变成金色"
        case .silver: return "还没有银卡。单词通过第一次隔天复习后，卡片会变成银色"
        case .plain, .all: return "这里还没有卡片"
        }
    }

    // MARK: - Cards

    private func cardView(_ card: Card) -> some View {
        Button { selected = card.record } label: {
            VStack(spacing: 0) {
                WordIllustration(word: card.record.word, cornerRadius: 0, maxPixel: 300)
                Text(card.record.word)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(frameStyle(card.tier), lineWidth: card.tier == .plain ? 1 : 1.5)
            }
            .shadow(color: card.tier == .gold ? Theme.gold.opacity(0.28) : .clear, radius: 10, y: 3)
            .overlay(alignment: .topTrailing) {
                if card.tier != .plain {
                    Image(systemName: card.tier == .gold ? "crown.fill" : "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(card.tier == .gold ? Theme.onGold : Theme.bgBottom)
                        .frame(width: 20, height: 20)
                        .background(card.tier.color, in: Circle())
                        .padding(6)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.record.word)，\(card.tier.title)")
        .accessibilityAddTraits(.isButton)
    }

    private func frameStyle(_ tier: Tier) -> AnyShapeStyle {
        switch tier {
        case .plain: return AnyShapeStyle(Theme.stroke)
        case .silver: return AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.8), Theme.silver.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .gold: return AnyShapeStyle(Theme.goldGradient)
        }
    }

    /// The card that unlocks with the next word: a reason to come back tomorrow.
    @ViewBuilder
    private var nextCardTeaser: some View {
        if let word = vm.currentWord, WordAtlas.hasImage(word.word) {
            Button { vm.startStudy() } label: {
                VStack(spacing: 0) {
                    WordIllustration(word: word.word, cornerRadius: 0, maxPixel: 120)
                        .blur(radius: 10)
                        .overlay {
                            Image(systemName: vm.canLearnNewWord ? "questionmark" : "lock.fill")
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .clipped()
                    Text(vm.canLearnNewWord ? "学新词解锁" : "明天解锁")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
            }
            .buttonStyle(PressableStyle())
            .disabled(!vm.canLearnNewWord || vm.mustTakeExamFirst)
            .accessibilityLabel(vm.canLearnNewWord ? "下一张卡片，学新词解锁" : "下一张卡片，明天解锁")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Mascot(size: 88)
            Text("学会第一个词，就能收到第一张插画卡")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Button("去学今天的单词") { vm.startStudy() }
                .buttonStyle(GoldButtonStyle())
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Large view of one collected card.
struct CollectionCardSheet: View {
    let vm: StudyViewModel
    let record: StudyRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let state = vm.reviewState(for: record)
        let tier = CollectionView.Tier(stage: state.stage)
        let atlas = WordAtlas.entry(for: record.word)

        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    WordIllustration(word: record.word, cornerRadius: 24)
                        .frame(maxWidth: 320)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(tier == .gold ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(tier.color.opacity(0.6)),
                                              lineWidth: tier == .plain ? 1 : 2)
                        }
                        .shadow(color: tier == .gold ? Theme.gold.opacity(0.3) : .black.opacity(0.3), radius: 18, y: 8)

                    VStack(spacing: 8) {
                        Text(tier.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tier == .gold ? Theme.onGold : Theme.bgBottom)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(tier == .plain ? Theme.textSecondary : tier.color, in: Capsule())
                        HStack(spacing: 10) {
                            Text(record.word)
                                .font(Theme.wordFont(34))
                                .foregroundStyle(Theme.textPrimary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            SpeakButton(text: record.word, size: 36)
                        }
                        Text(record.meaning)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        MemoryNodeTrack(stage: state.stage)
                        Text(upgradeHint(state.stage))
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .card()

                    if let example = atlas?.examples.first {
                        ExampleSentences(word: record.word, examples: [example])
                            .card()
                    }
                }
                .padding()
                .readableWidth(520)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(Theme.bgTop)
    }

    private func upgradeHint(_ stage: Int) -> String {
        if stage < CollectionView.Tier.silverStage {
            return "再按时复习 \(CollectionView.Tier.silverStage - stage) 次升级为银卡"
        }
        if stage < SpacedRepetition.masteredStage {
            let left = SpacedRepetition.masteredStage - stage
            return "再按时复习 \(left) 次升级为金卡"
        }
        return "已是金卡，小象会隔得更久再请你复习它"
    }
}
