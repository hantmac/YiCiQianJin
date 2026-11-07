import SwiftUI

struct HomeView: View {
    @Bindable var vm: StudyViewModel

    var body: some View {
        AdaptiveSplit {
            column {
                topBar
                greeting
                heroCard
                memoryCard
            }
        } secondary: {
            column {
                shortcutGrid
                bookCard
                levelRow
            }
            .padding(.top, 8)
        } compact: {
            column {
                topBar
                greeting
                heroCard
                memoryCard
                shortcutGrid
                bookCard
                levelRow
            }
            .readableWidth()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { vm.go(.settings) } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }
        }
    }

    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { vm.go(.achievements) } label: {
                CoinLabel(amount: vm.stats.xp, font: Theme.number(.subheadline))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.stroke))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("千金值 \(vm.stats.xp)，查看等级与成就")

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(vm.hasStudiedToday ? Theme.flame : Theme.textTertiary)
                    .symbolEffect(.bounce, value: vm.hasStudiedToday)
                Text("\(vm.stats.currentStreak)")
                    .font(Theme.number(.subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("连续学习 \(vm.stats.currentStreak) 天")
        }
        .padding(.top, 4)
    }

    private var greeting: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.greetingWord())
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Mascot(size: 60)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let streak = vm.stats.currentStreak
        if vm.hasStudiedToday {
            return streak > 1 ? "连续 \(streak) 天，今天也没有偷懒" : "今天的千金已入账，明天见"
        }
        if streak > 0 {
            return "已连续 \(streak) 天，今天学完就是第 \(streak + 1) 天"
        }
        return "每天一个词，从今天开始积累"
    }

    static func greetingWord(_ date: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        default: return "晚上好"
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroBody
            Divider().overlay(Theme.stroke)
            stepsRow
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.surfaceStrong)
            // Gilt edge marks the one card that matters today.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Theme.gold.opacity(0.45), Theme.gold.opacity(0.08)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var heroBody: some View {
        if vm.mustTakeExamFirst {
            heroContent(
                symbol: "checklist",
                eyebrow: "第一步 · 昨日考试",
                title: "先考昨天的 \(vm.examWords.count) 个词",
                detail: "考完解锁今天的新词，全部答对额外 +\(LearningStats.Reward.perfectExam) 金"
            )
            Button("开始考试") { vm.startExam() }
                .buttonStyle(GoldButtonStyle())
        } else if vm.isBookComplete {
            heroContent(symbol: "trophy.fill", eyebrow: "词书完成", title: "这本词书已经学完了",
                        detail: "换一本新词书，继续积累千金")
            Button("选择下一本词书") { vm.go(.bookSelect) }
                .buttonStyle(GoldButtonStyle())
        } else if vm.canLearnNewWord, let word = vm.currentWord {
            newWordTeaser(word)
            Button(vm.hasStudiedToday ? "继续学习" : "开始今日学习") { vm.startStudy() }
                .buttonStyle(GoldButtonStyle())
        } else {
            doneContent
        }
    }

    /// Today's picture, blurred: a small riddle that makes opening the word worth it.
    private func newWordTeaser(_ word: Word) -> some View {
        let hasImage = WordAtlas.hasImage(word.word)
        let index = vm.state.currentWordIndex + 1
        return HStack(alignment: .center, spacing: 16) {
            if hasImage {
                WordIllustration(word: word.word, cornerRadius: 18, maxPixel: 240)
                    .blur(radius: 9)
                    .overlay {
                        Image(systemName: "questionmark")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.textPrimary.opacity(0.9))
                            .shadow(color: .black.opacity(0.4), radius: 6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(width: 92, height: 92)
                    .accessibilityHidden(true)
            } else {
                heroSymbol("sparkles")
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(vm.hasStudiedToday ? "Pro · 今日已学 \(vm.todayRecords.count) 词" : "今日一词")
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.gold)
                Text(hasImage ? "猜猜画里是哪个词" : (vm.hasStudiedToday ? "继续学下一个新词" : "今天的新词已就位"))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("\(vm.currentBook?.name ?? "") · 第 \(index) 个词 · +\(LearningStats.Reward.newWord) 金")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func heroSymbol(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title2.weight(.semibold))
            .foregroundStyle(Theme.gold)
            .frame(width: 56, height: 56)
            .background(Theme.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)
    }

    private func heroContent(symbol: String, eyebrow: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            heroSymbol(symbol)
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var doneContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今日一词已收入词库")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("下一个新词 \(Self.countdown(to: Self.nextMidnight(after: context.date), from: context.date)) 后解锁")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }

        if let record = vm.todayRecords.last {
            HStack(spacing: 12) {
                WordThumbnail(word: record.word, size: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.word)
                        .font(Theme.wordFont(26))
                        .foregroundStyle(Theme.textPrimary)
                    Text(record.meaning)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                SpeakButton(text: record.word)
            }
        }

        if !vm.state.isPremium && vm.dueReviews.isEmpty {
            Button { vm.go(.premium) } label: {
                Label("还想多背？升级 Pro 无限学习", systemImage: "crown")
            }
            .buttonStyle(GlassButtonStyle(height: 46))
        }
    }

    static func nextMidnight(after date: Date) -> Date {
        Calendar.current.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? date
    }

    static func countdown(to target: Date, from now: Date) -> String {
        let s = max(0, Int(target.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }

    // MARK: - Steps

    private struct Step: Identifiable {
        let id: String
        let title: String
        let detail: String
        let done: Bool
        let action: (() -> Void)?
    }

    private var steps: [Step] {
        var list: [Step] = []
        if !vm.examWords.isEmpty {
            list.append(Step(id: "exam", title: "昨日考试",
                             detail: vm.examPending ? "\(vm.examWords.count) 词" : "已完成",
                             done: !vm.examPending,
                             action: vm.examPending ? { vm.startExam() } : nil))
        }
        list.append(Step(id: "new", title: "今日新词",
                         detail: vm.hasStudiedToday ? "已学 \(vm.todayRecords.count)" : (vm.mustTakeExamFirst ? "考完解锁" : "待学习"),
                         done: vm.hasStudiedToday,
                         action: (!vm.hasStudiedToday && !vm.mustTakeExamFirst && vm.canLearnNewWord) ? { vm.startStudy() } : nil))
        if vm.stats.totalWords > 0 {
            let due = vm.dueReviews.count
            list.append(Step(id: "review", title: "温故复习",
                             detail: due > 0 ? "\(due) 词到期" : "已清空",
                             done: due == 0,
                             action: due > 0 ? { vm.startReview() } : nil))
        }
        return list
    }

    private var stepsRow: some View {
        HStack(spacing: 8) {
            ForEach(steps) { step in
                Button { step.action?() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundStyle(step.done ? Theme.correct : Theme.textTertiary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(step.done ? Theme.textSecondary : Theme.textPrimary)
                            Text(step.detail)
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .disabled(step.action == nil)
                .accessibilityLabel("\(step.title)，\(step.done ? "已完成" : step.detail)")
            }
        }
    }

    // MARK: - Memory

    @ViewBuilder
    private var memoryCard: some View {
        let due = vm.dueReviews
        VStack(alignment: .leading, spacing: 12) {
            Button { vm.go(.memory) } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("记忆曲线")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    if let retention = vm.averageRetention {
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.percent(retention))
                                    .font(.system(size: 40, weight: .semibold, design: .serif))
                                    .foregroundStyle(Theme.textPrimary)
                                    .contentTransition(.numericText())
                                Text("平均记忆保持率")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            MemorySparkline()
                                .frame(height: 52)
                                .accessibilityHidden(true)
                        }
                    } else {
                        Text("学完第一个词后，这里会按艾宾浩斯遗忘曲线安排复习：5 分钟、30 分钟、12 小时，再到 1、2、4、7、15 天。")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("记忆曲线\(vm.averageRetention.map { "，平均记忆保持率 \(Self.percent($0))" } ?? "")")

            if vm.averageRetention != nil {
                memoryStatus(dueCount: due.count)
            }
            if !due.isEmpty {
                let reviewButton = Button("温故复习 \(due.count) 个词 · 每词 +\(LearningStats.Reward.reviewCorrect) 金") { vm.startReview() }
                // Gold only when nothing else on the screen asks for an action.
                if heroHasPrimaryAction {
                    reviewButton.buttonStyle(GlassButtonStyle(height: 50))
                } else {
                    reviewButton.buttonStyle(GoldButtonStyle())
                }
            }
        }
        .card()
    }

    private var heroHasPrimaryAction: Bool {
        vm.mustTakeExamFirst || vm.isBookComplete || vm.canLearnNewWord
    }

    @ViewBuilder
    private func memoryStatus(dueCount: Int) -> some View {
        if dueCount > 0 {
            Label("\(dueCount) 个词快要忘了，现在复习正是时候", systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.flame)
        } else if let next = vm.nextUpcomingReview {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text("下次复习 \(next.record.word) · \(MemoryFormat.relative(next.state.dueAt, from: context.date))")
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if !vm.state.reviewAlertsEnabled {
                    Button("到点提醒我") {
                        Task { @MainActor in
                            if await vm.setReviewAlerts(enabled: true) {
                                vm.showToast("已开启复习提醒")
                            } else {
                                vm.showToast("请在系统设置中允许通知")
                            }
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                }
            }
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
        }
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    // MARK: - Shortcuts

    private var shortcutGrid: some View {
        let games = GameRules.best(.blitz, in: vm.state.gameRecords).map { "最高 \($0) 分" } ?? "2 款"
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            shortcut("我的词库", value: "\(vm.stats.totalWords) 词", symbol: "books.vertical", tint: Color(red: 0.55, green: 0.75, blue: 0.98)) { vm.go(.library) }
            shortcut("插画图鉴", value: "\(vm.stats.collectedCards) 张", symbol: "photo.stack", tint: Theme.gold) { vm.go(.collection) }
            shortcut("小游戏", value: games, symbol: "gamecontroller", tint: Theme.flame) { vm.go(.games) }
            shortcut("学习日历", value: "\(vm.stats.studyDays) 天", symbol: "calendar", tint: Theme.correct) { vm.go(.calendar) }
        }
    }

    private func shortcut(_ title: String, value: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .card(padding: 12, radius: 18)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(value)")
    }

    // MARK: - Book & level

    @ViewBuilder
    private var bookCard: some View {
        if let book = vm.currentBook {
            let total = book.words.count
            let current = min(vm.state.currentWordIndex, total)
            let progress = Double(current) / Double(max(total, 1))
            HStack(spacing: 14) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 4, tint: AnyShapeStyle(book.tint))
                    Image(systemName: book.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(book.tint)
                }
                .frame(width: 46, height: 46)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("已学 \(current)/\(total) · \(String(format: "%.1f", progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button("更换") { vm.go(.bookSelect) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                    .accessibilityLabel("更换词书")
            }
            .card(padding: 14, radius: 18)
        }
    }

    private var levelRow: some View {
        let level = vm.level
        let xp = vm.stats.xp
        return Button { vm.go(.achievements) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Lv.\(level.index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    Text(level.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if let next = level.nextXP, let title = level.nextTitle {
                        Text("再赚 \(next - xp) 金晋升「\(title)」")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("已登顶，千金状元！")
                            .font(.caption)
                            .foregroundStyle(Theme.gold)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                CapsuleBar(progress: level.progress(xp: xp), height: 5)
            }
            .card(padding: 14, radius: 18)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("等级与成就，Lv.\(level.index + 1) \(level.title)")
    }
}
