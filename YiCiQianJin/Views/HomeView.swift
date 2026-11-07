import SwiftUI

/// 背单词 tab: today's count and one button. Everything else lives in the other tabs.
struct HomeView: View {
    @Bindable var vm: StudyViewModel

    var body: some View {
        let plan = vm.todayPlan
        AdaptiveSplit {
            centered { picture(plan, side: 300) }
        } secondary: {
            centered {
                VStack(alignment: .leading, spacing: 24) {
                    summary(plan)
                    actions(plan)
                }
                .padding(.horizontal, 24)
            }
        } compact: {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 12)
                        picture(plan, side: min(260, proxy.size.height * 0.34))
                        Spacer(minLength: 28)
                        summary(plan)
                        Spacer(minLength: 28)
                        actions(plan)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .frame(minHeight: proxy.size.height)
                    .readableWidth(520)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { streakChip }
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack { Spacer(); content(); Spacer() }
            .frame(maxWidth: .infinity)
    }

    // MARK: - Streak

    private var streakChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(vm.hasStudiedToday ? Theme.flame : Theme.textTertiary)
                .symbolEffect(.bounce, value: vm.hasStudiedToday)
            Text("\(vm.stats.currentStreak)")
                .font(Theme.number(.subheadline))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("连续学习 \(vm.stats.currentStreak) 天")
    }

    // MARK: - Picture

    /// Today's new word, blurred: a small riddle that makes opening the word worth it.
    @ViewBuilder
    private func picture(_ plan: TodayPlan, side: CGFloat) -> some View {
        if plan.newWords > 0, let word = vm.currentWord, WordAtlas.hasImage(word.word) {
            WordIllustration(word: word.word, cornerRadius: 28, maxPixel: 360)
                .blur(radius: 16)
                .overlay {
                    Image(systemName: "questionmark")
                        .font(.system(size: side * 0.2, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.textPrimary.opacity(0.92))
                        .shadow(color: .black.opacity(0.35), radius: 8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Theme.gold.opacity(0.5), Theme.gold.opacity(0.05)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
                .frame(width: side, height: side)
                .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
                .accessibilityLabel("今日新词的插画，学习后揭晓")
        } else if let record = doneWord(plan) {
            // Done: today's word, now revealed.
            VStack(spacing: 14) {
                WordIllustration(word: record.word, cornerRadius: 28, maxPixel: 360)
                    .frame(width: side * 0.8, height: side * 0.8)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                HStack(spacing: 10) {
                    Text(record.word)
                        .font(Theme.wordFont(28))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    SpeakButton(text: record.word, size: 34)
                }
            }
        } else {
            Mascot(size: min(side * 0.6, 150))
        }
    }

    private func doneWord(_ plan: TodayPlan) -> StudyRecord? {
        guard plan.total == 0, let record = vm.todayRecords.last, WordAtlas.hasImage(record.word) else { return nil }
        return record
    }

    // MARK: - Summary

    @ViewBuilder
    private func summary(_ plan: TodayPlan) -> some View {
        if vm.isBookComplete && plan.total == 0 {
            textBlock(eyebrow: "词书完成", title: "「\(vm.currentBook?.name ?? "")」已经学完了",
                      detail: "换一本新词书，继续积累千金")
        } else if plan.total > 0 {
            VStack(spacing: 10) {
                Text("今日学习")
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.gold)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(plan.total)")
                        .font(.system(size: 72, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("词")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                VStack(spacing: 4) {
                    Text(breakdown(plan))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text("约 \(plan.minutes) 分钟")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        } else {
            doneSummary
        }
    }

    private func breakdown(_ plan: TodayPlan) -> String {
        var parts: [String] = []
        if plan.exam > 0 { parts.append("昨日考试 \(plan.exam)") }
        if plan.newWords > 0 { parts.append("新词 \(plan.newWords)") }
        if plan.review > 0 { parts.append("复习 \(plan.review)") }
        return parts.joined(separator: " · ")
    }

    private func textBlock(eyebrow: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(eyebrow)
                .font(Theme.eyebrow)
                .foregroundStyle(Theme.gold)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var doneSummary: some View {
        VStack(spacing: 8) {
            Text("今天学完了")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 4) {
                    if let next = vm.nextUpcomingReview,
                       next.state.dueAt < Self.nextMidnight(after: context.date) {
                        Text("下次复习 \(MemoryFormat.relative(next.state.dueAt, from: context.date))")
                    }
                    Text("下一个新词 \(Self.countdown(to: Self.nextMidnight(after: context.date), from: context.date)) 后解锁")
                        .monospacedDigit()
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    static func nextMidnight(after date: Date) -> Date {
        Calendar.current.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? date
    }

    static func countdown(to target: Date, from now: Date) -> String {
        let s = max(0, Int(target.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }

    // MARK: - Actions

    @ViewBuilder
    private func actions(_ plan: TodayPlan) -> some View {
        VStack(spacing: 10) {
            if plan.total > 0 {
                Button(startTitle(plan)) { vm.startToday() }
                    .buttonStyle(GoldButtonStyle())
            } else if vm.isBookComplete {
                Button("选择下一本词书") { vm.go(.bookSelect) }
                    .buttonStyle(GoldButtonStyle())
            } else if vm.canLearnNewWord {
                // Pro: today's word is done, more are available.
                Button("再学一个新词") { vm.startStudy() }
                    .buttonStyle(GlassButtonStyle(height: 54))
            } else if !vm.state.isPremium {
                Button { vm.go(.premium) } label: {
                    Label("还想多背？升级 Pro 无限学习", systemImage: "crown")
                }
                .buttonStyle(GlassButtonStyle(height: 50))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func startTitle(_ plan: TodayPlan) -> String {
        if plan.exam == 0 && plan.newWords == 0 { return "开始复习" }
        return vm.stats.totalWords == 0 ? "开始今日学习" : "开始学习"
    }
}
