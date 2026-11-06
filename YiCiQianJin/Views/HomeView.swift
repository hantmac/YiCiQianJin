import SwiftUI

struct HomeView: View {
    @Bindable var vm: StudyViewModel

    var body: some View {
        AdaptiveSplit {
            column {
                topBar
                greeting
                heroCard
                tasksCard
            }
        } secondary: {
            column {
                levelCard
                shortcutGrid
                bookCard
            }
        } compact: {
            column {
                topBar
                greeting
                heroCard
                tasksCard
                levelCard
                shortcutGrid
                bookCard
            }
            .readableWidth()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { vm.go(.settings) } label: {
                    Label("设置", systemImage: "gearshape.fill")
                }
            }
        }
    }

    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { vm.go(.achievements) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(Theme.gold)
                    Text(vm.level.title)
                        .foregroundStyle(.white)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Theme.surface, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("等级 \(vm.level.title)，查看成就")

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(vm.hasStudiedToday ? Theme.flame : Color.white.opacity(0.45))
                    .symbolEffect(.bounce, value: vm.hasStudiedToday)
                Text("\(vm.stats.currentStreak)")
                    .font(Theme.number(.subheadline))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Theme.surface, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("连续学习 \(vm.stats.currentStreak) 天")
        }
        .padding(.top, 8)
    }

    private var greeting: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.greetingWord())
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Mascot(size: 72)
        }
        .padding(.top, 4)
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

    @ViewBuilder
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            } else if vm.canLearnNewWord {
                let index = vm.state.currentWordIndex + 1
                heroContent(
                    symbol: "sparkles",
                    eyebrow: vm.hasStudiedToday ? "Pro · 今日已学 \(vm.todayRecords.count) 词" : "今日一词",
                    title: vm.hasStudiedToday ? "继续学下一个新词" : "今天的新词已就位",
                    detail: "\(vm.currentBook?.name ?? "") · 第 \(index) 个词 · +\(LearningStats.Reward.newWord) 金"
                )
                Button(vm.hasStudiedToday ? "继续学习" : "开始今日学习") { vm.startStudy() }
                    .buttonStyle(GoldButtonStyle())
            } else {
                doneContent
            }
        }
        .card(padding: 20, radius: 26, fill: Theme.surfaceStrong)
    }

    private func heroContent(symbol: String, eyebrow: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.onGold)
                .frame(width: 52, height: 52)
                .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var doneContent: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.correct)
                .frame(width: 52, height: 52)
                .background(Theme.correct.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("今日一词已收入词库")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("下一个新词 \(Self.countdown(to: Self.nextMidnight(after: context.date), from: context.date)) 后解锁")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }

        if let record = vm.todayRecords.last {
            HStack(spacing: 12) {
                WordThumbnail(word: record.word, size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.word)
                        .font(Theme.wordFont(26))
                        .foregroundStyle(.white)
                    Text(record.meaning)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                SpeakButton(text: record.word)
            }
            .card(padding: 14, radius: 18)
        }

        if !vm.dueReviews.isEmpty {
            Button("温故复习 \(vm.dueReviews.count) 个词 · 每词 +\(LearningStats.Reward.reviewCorrect) 金") { vm.startReview() }
                .buttonStyle(GoldButtonStyle())
        } else if !vm.state.isPremium {
            Button { vm.go(.premium) } label: {
                Label("还想多背？升级 Pro 无限学习", systemImage: "crown.fill")
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    static func nextMidnight(after date: Date) -> Date {
        Calendar.current.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? date
    }

    static func countdown(to target: Date, from now: Date) -> String {
        let s = max(0, Int(target.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }

    // MARK: - Tasks

    private struct DailyTask: Identifiable {
        let id: String
        let title: String
        let detail: String
        let done: Bool
        let action: (() -> Void)?
    }

    private var tasks: [DailyTask] {
        var list: [DailyTask] = []
        if !vm.examWords.isEmpty {
            list.append(DailyTask(
                id: "exam", title: "昨日考试",
                detail: vm.examPending ? "\(vm.examWords.count) 个词等你来考" : "已完成",
                done: !vm.examPending,
                action: vm.examPending ? { vm.startExam() } : nil))
        }
        list.append(DailyTask(
            id: "new", title: "学习今日新词",
            detail: vm.hasStudiedToday ? "已学 \(vm.todayRecords.count) 个" : (vm.mustTakeExamFirst ? "考完昨日考试后解锁" : "+\(LearningStats.Reward.newWord) 金"),
            done: vm.hasStudiedToday,
            action: (!vm.hasStudiedToday && !vm.mustTakeExamFirst && vm.canLearnNewWord) ? { vm.startStudy() } : nil))
        if vm.stats.totalWords > 0 {
            let due = vm.dueReviews.count
            list.append(DailyTask(
                id: "review", title: "温故复习",
                detail: due > 0 ? "\(due) 个词到了复习时间" : "暂无待复习单词",
                done: due == 0,
                action: due > 0 ? { vm.startReview() } : nil))
        }
        return list
    }

    private var tasksCard: some View {
        let list = tasks
        let doneCount = list.filter(\.done).count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日任务")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(doneCount == list.count ? "今日全勤" : "\(doneCount)/\(list.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(doneCount == list.count ? Theme.gold : Theme.textSecondary)
            }
            ForEach(list) { task in
                Button { task.action?() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(task.done ? Theme.correct : Color.white.opacity(0.5))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(task.done ? Theme.textSecondary : .white)
                                .strikethrough(task.done, color: Theme.textTertiary)
                            Text(task.detail)
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                        if task.action != nil {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .disabled(task.action == nil)
                .accessibilityLabel("\(task.title)，\(task.done ? "已完成" : task.detail)")
            }
        }
        .card()
    }

    // MARK: - Level

    private var levelCard: some View {
        let level = vm.level
        let xp = vm.stats.xp
        return Button { vm.go(.achievements) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("千金值")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                        CoinLabel(amount: xp, font: Theme.number(.title2))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Lv.\(level.index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.gold)
                        Text(level.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                CapsuleBar(progress: level.progress(xp: xp))
                if let next = level.nextXP, let title = level.nextTitle {
                    Text("再赚 \(next - xp) 金晋升「\(title)」")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("已登顶，千金状元！")
                        .font(.caption)
                        .foregroundStyle(Theme.gold)
                }
            }
            .card()
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Shortcuts

    private var shortcutGrid: some View {
        let unlocked = Achievement.unlocked(vm.stats).count
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            shortcut("我的词库", value: "\(vm.stats.totalWords) 词", symbol: "books.vertical.fill", tint: Color(red: 0.45, green: 0.8, blue: 1)) { vm.go(.library) }
            shortcut("成就徽章", value: "\(unlocked)/\(Achievement.all.count)", symbol: "rosette", tint: Theme.gold) { vm.go(.achievements) }
            shortcut("学习日历", value: "\(vm.stats.studyDays) 天", symbol: "calendar", tint: Theme.correct) { vm.go(.calendar) }
            shortcut(vm.state.isPremium ? "Pro 会员" : "升级 Pro", value: vm.state.isPremium ? "已解锁" : "无限学习", symbol: "crown.fill", tint: Theme.flame) { vm.go(.premium) }
        }
    }

    private func shortcut(_ title: String, value: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(Theme.number(.headline))
                        .foregroundStyle(.white)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .card(padding: 16)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(value)")
    }

    // MARK: - Book

    @ViewBuilder
    private var bookCard: some View {
        if let book = vm.currentBook {
            let total = book.words.count
            let current = min(vm.state.currentWordIndex, total)
            let progress = Double(current) / Double(max(total, 1))
            HStack(spacing: 14) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 5, tint: AnyShapeStyle(book.tint))
                    Image(systemName: book.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(book.tint)
                }
                .frame(width: 54, height: 54)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.name)
                        .font(.headline)
                        .foregroundStyle(.white)
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
            .card()
        }
    }
}
