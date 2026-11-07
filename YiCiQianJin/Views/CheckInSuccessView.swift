import SwiftUI

/// Reward overlay: daily check-in, level-ups and newly unlocked achievements.
struct CheckInSuccessView: View {
    let celebration: Celebration
    let stats: LearningStats
    let level: Level
    var actionTitle = "收下千金"
    let onClose: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let encouragements = [
        "积少成多，一年也能背 365 个词！",
        "慢慢来，比较快。",
        "今天的你比昨天多认识了一个词。",
        "罗马不是一天建成的，词汇量也不是。",
        "一词千金，小象今天又帮你攒了一笔！",
        "坚持的人，运气都不会太差。",
    ]
    @State private var encouragement = encouragements.randomElement()!

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            if !reduceMotion {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Scrolls when the card is taller than the display (short outer display, large text).
            GeometryReader { proxy in
                ScrollView {
                    // Full width so the card is centered on wide (landscape / unfolded) displays.
                    card.frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { appeared = true }
        }
    }

    private var card: some View {
        VStack(spacing: 18) {
            header

            if let newLevel = celebration.newLevel {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("晋升 Lv.\(newLevel.index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.gold)
                        Text("恭喜成为「\(newLevel.title)」")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                }
                .card(padding: 14, radius: 16, fill: Theme.gold.opacity(0.16))
            }

            levelProgress

            if !celebration.newAchievements.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("解锁新成就")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    ForEach(celebration.newAchievements) { achievement in
                        HStack(spacing: 12) {
                            AchievementBadge(symbol: achievement.symbol, unlocked: true, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(achievement.detail)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }
                .card(padding: 14, radius: 16)
            }

            Button(actionTitle, action: onClose)
                .buttonStyle(GoldButtonStyle())
        }
        .padding(24)
        .background(
            LinearGradient(colors: [Color(red: 0.11, green: 0.14, blue: 0.23), Color(red: 0.07, green: 0.09, blue: 0.15)],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Theme.gold.opacity(0.35)))
        .frame(maxWidth: 440)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var header: some View {
        if celebration.kind == .checkIn {
            VStack(spacing: 8) {
                Mascot(size: 112)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .rotationEffect(.degrees(appeared ? 0 : -8))
                    .animation(.spring(duration: 0.6, bounce: 0.5).delay(0.1), value: appeared)
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(LinearGradient(colors: [Theme.gold, Theme.flame], startPoint: .top, endPoint: .bottom))
                        .symbolEffect(.bounce, value: appeared)
                    Text("连续 \(stats.currentStreak) 天")
                        .foregroundStyle(Theme.textPrimary)
                }
                .font(Theme.number(.largeTitle))
                .accessibilityElement(children: .combine)
                Text("打卡成功 · \(encouragement)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 18) {
                    CoinLabel(amount: celebration.xpGained, font: .headline)
                        .accessibilityLabel("获得 \(celebration.xpGained) 金")
                    Label("\(stats.totalWords) 词", systemImage: "books.vertical.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, 4)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.goldGradient)
                    .symbolEffect(.bounce, value: appeared)
                Text("新的里程碑")
                    .font(.title.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("本次获得 \(celebration.xpGained) 金")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var levelProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lv.\(level.index + 1) \(level.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let next = level.nextXP {
                    Text("\(stats.xp)/\(next)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            CapsuleBar(progress: appeared ? level.progress(xp: stats.xp) : 0)
                .animation(.easeOut(duration: 0.9).delay(0.2), value: appeared)
        }
    }
}

// MARK: - Confetti

/// Lightweight particle burst drawn with Canvas (no assets, no dependencies).
struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let drift: Double
        let spin: Double
        let size: Double
        let color: Color
    }

    private let pieces: [Piece] = (0..<70).map { _ in
        Piece(x: .random(in: 0...1), delay: .random(in: 0...0.6), speed: .random(in: 0.35...0.7),
              drift: .random(in: -40...40), spin: .random(in: 2...7), size: .random(in: 6...11),
              color: [Theme.gold, Theme.goldDeep, Theme.gold, Theme.textPrimary, Theme.silver].randomElement()!)
    }
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            Canvas { ctx, size in
                for p in pieces {
                    let life = t - p.delay
                    guard life > 0 else { continue }
                    let y = -20 + life * p.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(life * 3 + p.x * 10) * p.drift
                    var piece = ctx
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(life * p.spin))
                    piece.opacity = max(0, 1 - life / 3.2)
                    piece.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)), with: .color(p.color))
                }
            }
        }
    }
}
