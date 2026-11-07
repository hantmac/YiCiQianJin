import SwiftUI

/// Game hub. Games quiz only words the user has learned and never change review schedules.
struct GamesView: View {
    @Bindable var vm: StudyViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("只用你学过的 \(vm.learnedWords.count) 个词出题，不会打乱复习安排。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)

                gameCard(.blitz, detail: "60 秒里尽量多答。连对越多每题越值钱，答错扣 \(GameRules.blitzPenalty) 秒。")
                gameCard(.match, detail: "\(GameRules.matchRounds) 轮，每轮 \(GameRules.matchPairsPerRound) 对，把单词和意思连起来，越快越好。")
                coinsToday
            }
            .padding()
            .readableWidth(640)
        }
        .scrollIndicators(.hidden)
        .pageChrome("小游戏") { vm.go(.home) }
    }

    private func gameCard(_ kind: GameKind, detail: String) -> some View {
        let unlocked = vm.canPlay(kind)
        let missing = kind.minimumWords - vm.learnedWords.count
        return Button { vm.startGame(kind) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: kind.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(unlocked ? Theme.gold : Theme.textTertiary)
                        .frame(width: 56, height: 56)
                        .background((unlocked ? Theme.gold : Theme.textTertiary).opacity(0.13),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title)
                            .font(.title3.bold())
                            .foregroundStyle(Theme.textPrimary)
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    Text(bestText(kind))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    if unlocked {
                        Text("开始")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.onGold)
                            .padding(.horizontal, 20)
                            .frame(height: 36)
                            .background(Theme.goldGradient, in: Capsule())
                    } else {
                        Label("再学 \(missing) 个词解锁", systemImage: "lock.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .card(padding: 18, radius: 22, fill: Theme.surfaceStrong)
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title)，\(unlocked ? bestText(kind) : "再学 \(missing) 个词解锁")")
        .accessibilityAddTraits(.isButton)
    }

    private func bestText(_ kind: GameKind) -> String {
        guard let best = GameRules.best(kind, in: vm.state.gameRecords) else { return "还没有记录" }
        switch kind {
        case .blitz: return "最高 \(best) 分"
        case .match: return "最快 \(GameFormat.clock(best))"
        }
    }

    private var coinsToday: some View {
        let correct = vm.state.gameRecords.filter { $0.date == vm.today }.reduce(0) { $0 + $1.correct }
        let earned = min(correct, LearningStats.Reward.gameDailyCap) * LearningStats.Reward.gameCorrect
        return HStack(spacing: 10) {
            Image(systemName: "yensign.circle.fill")
                .foregroundStyle(Theme.gold)
            Text("每天前 \(LearningStats.Reward.gameDailyCap) 次答对各 +\(LearningStats.Reward.gameCorrect) 金")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("今日 \(earned)/\(LearningStats.Reward.gameDailyCap)")
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .card(padding: 14, radius: 16)
    }
}

enum GameFormat {
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Shared summary

struct GameSummaryView: View {
    let title: String
    let value: String
    let unit: String
    let isRecord: Bool
    let stats: [(label: String, value: String)]
    let coins: Int
    let missed: [StudyRecord]
    let onReplay: () -> Void
    let onExit: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(Theme.eyebrow)
                        .foregroundStyle(Theme.gold)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 64, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.textPrimary)
                            .contentTransition(.numericText())
                        Text(unit)
                            .font(.headline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if isRecord {
                        Label("新纪录", systemImage: "sparkles")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.onGold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Theme.goldGradient, in: Capsule())
                            .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                            .opacity(appeared || reduceMotion ? 1 : 0)
                    }
                }
                .padding(.top, 28)

                HStack(spacing: 0) {
                    ForEach(stats.indices, id: \.self) { i in
                        VStack(spacing: 4) {
                            Text(stats[i].value)
                                .font(Theme.number(.title3))
                                .foregroundStyle(Theme.textPrimary)
                            Text(stats[i].label)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                    VStack(spacing: 4) {
                        Text("+\(coins)")
                            .font(Theme.number(.title3))
                            .foregroundStyle(Theme.gold)
                        Text("获得千金")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
                .card(padding: 16)

                if !missed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("这几个词再看一眼")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        ForEach(missed) { record in
                            HStack(spacing: 12) {
                                WordThumbnail(word: record.word, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.word)
                                        .font(Theme.wordFont(18))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(record.meaning)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                SpeakButton(text: record.word, size: 32)
                            }
                        }
                    }
                    .card()
                }

                VStack(spacing: 10) {
                    Button("再来一局", action: onReplay)
                        .buttonStyle(GoldButtonStyle())
                    Button("返回小游戏", action: onExit)
                        .buttonStyle(GlassButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .readableWidth(520)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.success, trigger: appeared) { _, new in new && isRecord }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.45).delay(0.15)) { appeared = true }
        }
    }
}
