import SwiftUI

/// Every learned word with its memory state; doubles as the mistakes notebook.
struct WordLibraryView: View {
    @Bindable var vm: StudyViewModel

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "全部"
        case due = "待复习"
        case mistakes = "易错词"
        case mastered = "已掌握"
        var id: String { rawValue }
    }

    private struct Entry: Identifiable {
        let record: StudyRecord
        let phonetic: String
        let state: ReviewState
        let mistakes: Int
        var id: String { record.wordKey }
    }

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var selected: StudyRecord?

    private var entries: [Entry] {
        let mistakes = vm.mistakeCounts
        return vm.state.studyRecords.uniqueWords().reversed().map { record in
            Entry(record: record,
                  phonetic: WordData.word(for: record)?.phonetic ?? "",
                  state: vm.reviewState(for: record),
                  mistakes: mistakes[record.word] ?? 0)
        }
    }

    private func filtered(_ all: [Entry]) -> [Entry] {
        let byFilter: [Entry]
        switch filter {
        case .all: byFilter = all
        case .due: byFilter = all.filter { SpacedRepetition.isDue($0.state, at: vm.now) }
        case .mistakes: byFilter = all.filter { $0.mistakes > 0 }.sorted { $0.mistakes > $1.mistakes }
        case .mastered: byFilter = all.filter { $0.state.stage >= SpacedRepetition.masteredStage }
        }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return byFilter }
        return byFilter.filter { $0.record.word.lowercased().contains(q) || $0.record.meaning.contains(q) }
    }

    var body: some View {
        let all = entries
        let shown = filtered(all)
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                summary(all)
                searchField
                filterBar
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .readableWidth(900)

            if shown.isEmpty {
                emptyState(hasWords: !all.isEmpty)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                             count: sizeClass == .regular ? 2 : 1), spacing: 10) {
                        ForEach(shown) { row($0) }
                    }
                    .padding()
                    .readableWidth(900)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .navigationTitle("词库")
        .navigationBarTitleDisplayMode(.inline) // the summary card is the page header
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $selected) { record in
            WordMemorySheet(vm: vm, record: record)
        }
    }

    private func summary(_ all: [Entry]) -> some View {
        let mastered = all.filter { $0.state.stage >= SpacedRepetition.masteredStage }.count
        let due = vm.dueReviews.count
        return HStack(spacing: 0) {
            summaryItem("\(all.count)", "已学")
            Divider().frame(height: 28).overlay(Theme.stroke)
            summaryItem("\(mastered)", "已掌握")
            Divider().frame(height: 28).overlay(Theme.stroke)
            summaryItem("\(due)", "待复习")
            if due > 0 {
                Button("去复习") { vm.startReview() }
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(Theme.onGold)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Theme.goldGradient, in: Capsule())
                    .padding(.leading, 8)
            }
        }
        .card(padding: 14)
    }

    private func summaryItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.number(.title3))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textTertiary)
            TextField("", text: $query, prompt: Text("搜索单词或释义").foregroundStyle(Theme.textTertiary))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary)
                }
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { item in
                Button {
                    filter = item
                } label: {
                    Text(item.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(filter == item ? Theme.onGold : Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(filter == item ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surface), in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(filter == item ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ entry: Entry) -> some View {
        let mastery = SpacedRepetition.mastery(of: entry.state.stage)
        return Button { selected = entry.record } label: { HStack(spacing: 12) {
            WordThumbnail(word: entry.record.word, size: 60)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.record.word)
                        .font(Theme.wordFont(20))
                        .foregroundStyle(Theme.textPrimary)
                    if !entry.phonetic.isEmpty {
                        Text(entry.phonetic)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
                Text(entry.record.meaning)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    masteryDots(entry.state.stage)
                    Text(mastery.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(mastery == .mastered ? Theme.correct : Theme.textTertiary)
                    if entry.mistakes > 0 {
                        Text("错 \(entry.mistakes) 次")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.wrong)
                    }
                    Text(nextReviewText(entry))
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: 0)
            Text(MemoryFormat.percent(SpacedRepetition.retention(entry.state, at: vm.now)))
                .font(Theme.number(.subheadline))
                .foregroundStyle(RetentionBar.color(SpacedRepetition.retention(entry.state, at: vm.now)))
                .accessibilityLabel("记忆保持率 \(MemoryFormat.percent(SpacedRepetition.retention(entry.state, at: vm.now)))")
        }
        .card(padding: 14, radius: 18)
        .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("查看记忆曲线")
    }

    private func masteryDots(_ stage: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<SpacedRepetition.masteredStage, id: \.self) { i in
                Circle()
                    .fill(i < stage ? Theme.gold : Theme.track)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func nextReviewText(_ entry: Entry) -> String {
        guard !SpacedRepetition.isDue(entry.state, at: vm.now) else { return "该复习了" }
        let relative = MemoryFormat.relative(entry.state.dueAt, from: vm.now)
        return relative + (relative.last?.isNumber == true ? " 复习" : "复习")
    }

    private func emptyState(hasWords: Bool) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Mascot(size: 96)
            Text(emptyTitle(hasWords: hasWords))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if !hasWords {
                Button("去学今天的单词") { vm.startStudy() }
                    .buttonStyle(GoldButtonStyle())
                    .frame(width: 220)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func emptyTitle(hasWords: Bool) -> String {
        guard hasWords else { return "词库还是空的，学会的单词会收在这里" }
        if !query.isEmpty { return "没有找到「\(query)」" }
        switch filter {
        case .due: return "没有待复习的单词，记得很牢！"
        case .mistakes: return "还没有答错过的单词"
        case .mastered: return "坚持复习，单词就会变成「已掌握」"
        case .all: return "暂无单词"
        }
    }
}
