import SwiftUI

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
