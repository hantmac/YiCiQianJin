import SwiftUI

enum GameFormat {
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Stars, filled from the left.
struct StarRow: View {
    let filled: Int
    var total = 3
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: size * 0.25) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: i < filled ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(i < filled ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.textTertiary))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(filled) 星")
    }
}

// MARK: - Shared summary

struct GameSummaryView: View {
    enum Badge {
        case rank(GameRules.Rank)
        case stars(Int, of: Int)
    }

    let vm: StudyViewModel
    let title: String
    let badge: Badge
    let value: String
    let unit: String
    let isRecord: Bool
    let stats: [(label: String, value: String)]
    let coins: Int
    let missed: [StudyRecord]
    let onReplay: () -> Void
    let onExit: () -> Void

    @State private var stamped = false
    @State private var addedToReview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                    .padding(.top, 20)
                statsCard
                if !missed.isEmpty { missedCard }
                VStack(spacing: 10) {
                    Button("再来一局", action: onReplay)
                        .buttonStyle(GoldButtonStyle())
                    Button("返回发现", action: onExit)
                        .buttonStyle(GlassButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .readableWidth(520)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.success, trigger: stamped) { _, new in new }
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 350))
            GameSound.shared.play(.rank)
            withAnimation(.spring(duration: 0.45, bounce: 0.35)) { stamped = true }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(Theme.eyebrow)
                .foregroundStyle(Theme.gold)
            badgeView
                .frame(height: 120)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            if isRecord {
                Label("新纪录", systemImage: "sparkles")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.onGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.goldGradient, in: Capsule())
                    .opacity(stamped ? 1 : 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var badgeView: some View {
        switch badge {
        case .rank(let rank):
            VStack(spacing: 4) {
                Text(rank.rawValue)
                    .font(.system(size: 92, weight: .bold, design: .serif))
                    .foregroundStyle(rank == .s || rank == .a ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.silver))
                    .shadow(color: Theme.gold.opacity(rank == .s ? 0.5 : 0), radius: 18)
                    // A stamp: lands from large to its place.
                    .scaleEffect(stamped || reduceMotion ? 1 : 2.2)
                    .rotationEffect(.degrees(stamped || reduceMotion ? 0 : -14))
                Text(rank.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .opacity(stamped || reduceMotion ? 1 : 0)
            .accessibilityLabel("评级 \(rank.rawValue)，\(rank.title)")
        case .stars(let n, let total):
            VStack(spacing: 10) {
                StarRow(filled: stamped ? n : 0, total: total, size: total > 3 ? 26 : 40)
                    .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.4), value: stamped)
                Text("\(n)/\(total) 星")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            ForEach(stats.indices, id: \.self) { i in
                statItem(stats[i].value, stats[i].label, tint: Theme.textPrimary)
            }
            statItem("+\(coins)", "获得千金", tint: Theme.gold)
        }
        .card(padding: 16)
    }

    private func statItem(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.number(.title3))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Missed words

    private var missedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这几个词没答上来")
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
            if addedToReview {
                Button {
                    vm.reviewAfterGame()
                } label: {
                    Label("去复习 \(min(vm.dueReviews.count, StudyViewModel.reviewBatch)) 词", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(GlassButtonStyle(height: 46))
                .transition(.opacity)
            } else {
                Button {
                    vm.addToReview(missed)
                    withAnimation(.easeOut(duration: 0.2)) { addedToReview = true }
                    vm.showToast("已加入复习，现在就能复习")
                } label: {
                    Label("把 \(missed.count) 个错词加入复习", systemImage: "plus.circle")
                }
                .buttonStyle(GlassButtonStyle(height: 46))
                .transition(.opacity)
            }
        }
        .card()
    }
}
