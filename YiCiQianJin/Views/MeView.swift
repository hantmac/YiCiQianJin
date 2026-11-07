import SwiftUI

/// 我的 tab: coins and level, streaks, word book and settings.
struct MeView: View {
    @Bindable var vm: StudyViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                levelCard
                statsRow
                VStack(spacing: 0) {
                    row("学习日历", detail: "\(vm.stats.studyDays) 天", symbol: "calendar") { vm.go(.calendar) }
                    divider
                    row("等级与成就", detail: "\(Achievement.unlocked(vm.stats).count)/\(Achievement.all.count) 枚徽章", symbol: "rosette") { vm.go(.achievements) }
                    divider
                    bookRow
                }
                .card(padding: 0)
                VStack(spacing: 0) {
                    row(vm.state.isPremium ? "Pro 会员" : "升级 Pro", detail: vm.state.isPremium ? "已解锁" : "无限学习新词", symbol: "crown") { vm.go(.premium) }
                    divider
                    row("设置", detail: nil, symbol: "gearshape") { vm.go(.settings) }
                }
                .card(padding: 0)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .readableWidth(640)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("我的")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var divider: some View {
        Divider().overlay(Theme.stroke).padding(.leading, 52)
    }

    // MARK: - Level

    private var levelCard: some View {
        let level = vm.level
        let xp = vm.stats.xp
        return Button { vm.go(.achievements) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Mascot(size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Lv.\(level.index + 1)")
                            .font(Theme.eyebrow)
                            .foregroundStyle(Theme.gold)
                        Text(level.title)
                            .font(.title3.bold())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                    CoinLabel(amount: xp, font: Theme.number(.title3))
                }
                CapsuleBar(progress: level.progress(xp: xp), height: 6)
                Group {
                    if let next = level.nextXP, let title = level.nextTitle {
                        Text("再赚 \(next - xp) 金晋升「\(title)」")
                    } else {
                        Text("已登顶，千金状元！")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            }
            .card(padding: 18, radius: 22, fill: Theme.surfaceStrong)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lv.\(level.index + 1) \(level.title)，\(xp) 金")
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat("\(vm.stats.currentStreak)", "连续天数")
            stat("\(vm.stats.longestStreak)", "最长连续")
            stat("\(vm.stats.totalWords)", "已学单词")
            stat("\(vm.stats.masteredWords)", "已掌握")
        }
        .card(padding: 14)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Theme.number(.title3))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Rows

    @ViewBuilder
    private var bookRow: some View {
        if let book = vm.currentBook {
            let total = book.words.count
            let learned = min(vm.state.currentWordIndex, total)
            row("当前词书", detail: "\(book.name) · \(learned)/\(total)", symbol: "book.closed") { vm.go(.bookSelect) }
                .accessibilityLabel("更换词书，当前 \(book.name)")
        } else {
            row("选择词书", detail: nil, symbol: "book.closed") { vm.go(.bookSelect) }
        }
    }

    private func row(_ title: String, detail: String?, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }
}
