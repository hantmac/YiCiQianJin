import SwiftUI

struct AchievementBadge: View {
    let symbol: String
    let unlocked: Bool
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: unlocked ? symbol : "lock.fill")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(unlocked ? Theme.onGold : Color.white.opacity(0.5))
            .frame(width: size, height: size)
            .background(unlocked ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surface), in: Circle())
            .overlay(Circle().strokeBorder(unlocked ? Color.white.opacity(0.5) : Theme.stroke, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

struct AchievementsView: View {
    @Bindable var vm: StudyViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        levelCard
                        rulesCard
                    }
                } else {
                    levelCard
                    rulesCard
                }
                achievementsSection
            }
            .padding()
            .readableWidth(1000)
        }
        .scrollIndicators(.hidden)
        .pageChrome("等级与成就") { vm.go(.home) }
    }

    private var levelCard: some View {
        let level = vm.level
        let xp = vm.stats.xp
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lv.\(level.index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    Text(level.title)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                CoinLabel(amount: xp, font: Theme.number(.title3))
            }
            CapsuleBar(progress: level.progress(xp: xp), height: 10)

            VStack(spacing: 0) {
                ForEach(Array(Level.ladder.enumerated()), id: \.offset) { i, rung in
                    HStack(spacing: 12) {
                        Image(systemName: i < level.index ? "checkmark.circle.fill" : (i == level.index ? "star.circle.fill" : "circle"))
                            .foregroundStyle(i <= level.index ? Theme.gold : Color.white.opacity(0.35))
                        Text("Lv.\(i + 1) \(rung.title)")
                            .font(.subheadline.weight(i == level.index ? .bold : .regular))
                            .foregroundStyle(i <= level.index ? .white : Theme.textTertiary)
                        Spacer()
                        Text("\(rung.xp) 金")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card(padding: 20, fill: Theme.surfaceStrong)
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("如何赚千金")
                .font(.headline)
                .foregroundStyle(.white)
            rule("学会一个新词", LearningStats.Reward.newWord)
            rule("昨日考试答对一题", LearningStats.Reward.examCorrect)
            rule("昨日考试全部答对", LearningStats.Reward.perfectExam)
            rule("温故复习答对一题", LearningStats.Reward.reviewCorrect)
        }
        .card()
    }

    private func rule(_ text: String, _ amount: Int) -> some View {
        HStack {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("+\(amount) 金")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.gold)
        }
    }

    private var achievementsSection: some View {
        let stats = vm.stats
        let unlockedCount = Achievement.unlocked(stats).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("成就徽章")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(unlockedCount)/\(Achievement.all.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 4 : 3), spacing: 12) {
                ForEach(Achievement.all) { achievement in
                    let unlocked = achievement.isUnlocked(stats)
                    VStack(spacing: 8) {
                        AchievementBadge(symbol: achievement.symbol, unlocked: unlocked)
                        Text(achievement.title)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(unlocked ? .white : Theme.textSecondary)
                        Text(achievement.detail)
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2, reservesSpace: true)
                        if !unlocked {
                            CapsuleBar(progress: Double(achievement.value(stats)) / Double(achievement.target), height: 4)
                            Text("\(achievement.value(stats))/\(achievement.target)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(unlocked ? Theme.gold.opacity(0.12) : Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(unlocked ? Theme.gold.opacity(0.4) : Theme.stroke))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(achievement.title)，\(achievement.detail)，\(unlocked ? "已解锁" : "进度 \(achievement.value(stats)) / \(achievement.target)")")
                }
            }
        }
    }
}
