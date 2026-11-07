import SwiftUI

/// 发现 tab: memory curve, illustrated collection and games.
struct DiscoverView: View {
    @Bindable var vm: StudyViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                memoryCard
                collectionCard
                sectionTitle("小游戏", detail: "只用学过的词出题，不打乱复习安排")
                gameCard(.blitz, detail: "60 秒里尽量多答，连对越多每题越值钱")
                gameCard(.match, detail: "\(GameRules.matchRounds) 轮，把单词和意思连起来，越快越好")
                coinsToday
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .readableWidth(640)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("发现")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.top, 10)
        .padding(.leading, 4)
    }

    // MARK: - Memory

    private var memoryCard: some View {
        let due = vm.dueReviews.count
        return Button { vm.go(.memory) } label: {
            VStack(alignment: .leading, spacing: 12) {
                header("记忆曲线", symbol: "waveform.path.ecg")
                if let retention = vm.averageRetention {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(MemoryFormat.percent(retention))
                                .font(.system(size: 38, weight: .semibold, design: .serif))
                                .foregroundStyle(Theme.textPrimary)
                            Text("平均记忆保持率")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        MemorySparkline()
                            .frame(height: 50)
                            .accessibilityHidden(true)
                    }
                    Text(due > 0 ? "\(due) 个词快要忘了" : "所有单词都还记得")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(due > 0 ? Theme.flame : Theme.textSecondary)
                } else {
                    Text("按艾宾浩斯遗忘曲线安排复习：5 分钟、30 分钟、12 小时，再到 1、2、4、7、15 天。学完第一个词后开始记录。")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card(padding: 18, radius: 22, fill: Theme.surfaceStrong)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("记忆曲线\(vm.averageRetention.map { "，平均记忆保持率 \(MemoryFormat.percent($0))" } ?? "")")
    }

    private func header(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.gold)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Collection

    private var collectionCard: some View {
        let cards = vm.learnedWords.reversed().filter { WordAtlas.hasImage($0.word) }
        let gold = cards.filter { vm.reviewState(for: $0).stage >= SpacedRepetition.masteredStage }.count
        return Button { vm.go(.collection) } label: {
            VStack(alignment: .leading, spacing: 12) {
                header("插画图鉴", symbol: "photo.stack")
                if cards.isEmpty {
                    Text("每学一个词得到一张插画卡，按时复习让它升级成银卡、金卡。")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                } else {
                    HStack(spacing: 8) {
                        ForEach(cards.prefix(4), id: \.wordKey) { record in
                            WordIllustration(word: record.word, cornerRadius: 10, maxPixel: 180)
                        }
                        ForEach(0..<max(0, 4 - cards.count), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.surface)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    Text("已收集 \(cards.count) 张 · 金卡 \(gold) 张")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .card(padding: 18, radius: 22)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("插画图鉴，已收集 \(cards.count) 张")
    }

    // MARK: - Games

    private func gameCard(_ kind: GameKind, detail: String) -> some View {
        let unlocked = vm.canPlay(kind)
        let missing = kind.minimumWords - vm.learnedWords.count
        return Button { vm.startGame(kind) } label: {
            HStack(spacing: 14) {
                Image(systemName: kind.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(unlocked ? Theme.gold : Theme.textTertiary)
                    .frame(width: 48, height: 48)
                    .background((unlocked ? Theme.gold : Theme.textTertiary).opacity(0.13),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(unlocked ? detail : "再学 \(missing) 个词解锁")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let best = bestText(kind) {
                        Text(best)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.gold)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: unlocked ? "play.fill" : "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(unlocked ? Theme.onGold : Theme.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(unlocked ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surface), in: Circle())
            }
            .card(padding: 14, radius: 20)
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title)，\(unlocked ? (bestText(kind) ?? "还没有记录") : "再学 \(missing) 个词解锁")")
        .accessibilityAddTraits(.isButton)
    }

    private func bestText(_ kind: GameKind) -> String? {
        guard let best = GameRules.best(kind, in: vm.state.gameRecords) else { return nil }
        switch kind {
        case .blitz: return "最高 \(best) 分"
        case .match: return "最快 \(GameFormat.clock(best))"
        }
    }

    private var coinsToday: some View {
        let correct = vm.state.gameRecords.filter { $0.date == vm.today }.reduce(0) { $0 + $1.correct }
        let earned = min(correct, LearningStats.Reward.gameDailyCap) * LearningStats.Reward.gameCorrect
        return HStack(spacing: 8) {
            Image(systemName: "yensign.circle.fill")
                .foregroundStyle(Theme.gold)
            Text("每天前 \(LearningStats.Reward.gameDailyCap) 次答对各 +\(LearningStats.Reward.gameCorrect) 金")
            Spacer()
            Text("今日 \(earned)/\(LearningStats.Reward.gameDailyCap)")
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textPrimary)
        }
        .font(.caption)
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 4)
    }
}
