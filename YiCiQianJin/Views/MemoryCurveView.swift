import SwiftUI
import Charts

/// 记忆曲线: how the Ebbinghaus review plan keeps words from fading, and where the user's words are.
struct MemoryCurveView: View {
    @Bindable var vm: StudyViewModel
    @State private var selected: StudyRecord?

    var body: some View {
        AdaptiveSplit {
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    curveCard
                }
                .padding()
            }
            .scrollIndicators(.hidden)
        } secondary: {
            ScrollView {
                VStack(spacing: 14) {
                    nodesCard
                    upcomingCard
                    weakWordsCard
                }
                .padding()
            }
            .scrollIndicators(.hidden)
        } compact: {
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    curveCard
                    nodesCard
                    upcomingCard
                    weakWordsCard
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                .readableWidth()
            }
            .scrollIndicators(.hidden)
        }
        .pageChrome("记忆曲线") { vm.go(.home) }
        .sheet(item: $selected) { record in
            WordMemorySheet(vm: vm, record: record)
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let words = vm.learnedWords
        let due = vm.dueReviews.count
        let mastered = vm.stats.masteredWords
        return VStack(alignment: .leading, spacing: 14) {
            Text("平均记忆保持率")
                .font(Theme.eyebrow)
                .foregroundStyle(Theme.gold)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(vm.averageRetention.map(MemoryFormat.percent) ?? "—")
                    .font(.system(size: 52, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            HStack(spacing: 0) {
                summaryItem("\(words.count)", "已学")
                summaryItem("\(due)", "快要忘了", tint: due > 0 ? Theme.flame : nil)
                summaryItem("\(mastered)", "已掌握")
            }
            if due > 0 {
                Button("温故复习 \(due) 个词 · 每词 +\(LearningStats.Reward.reviewCorrect) 金") { vm.startReview() }
                    .buttonStyle(GoldButtonStyle())
            } else if let next = vm.nextUpcomingReview {
                Label("下次复习：\(next.record.word) · \(MemoryFormat.relative(next.state.dueAt, from: vm.now))", systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .card(padding: 20, radius: 24, fill: Theme.surfaceStrong)
    }

    private func summaryItem(_ value: String, _ label: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.number(.title3))
                .foregroundStyle(tint ?? Theme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Curve

    private var curveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("为什么要按时复习")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            ForgettingCurveChart()
                .frame(height: 200)
            HStack(spacing: 16) {
                legend(color: Theme.gold, dashed: false, text: "按节点复习")
                legend(color: Theme.textTertiary, dashed: true, text: "学完不复习")
            }
            Text("艾宾浩斯发现，学完不复习，1 天后只记得约三成。小象在你快要忘记（保持率降到 80%）时安排复习，每复习一次，下一次遗忘就慢一些，间隔从 5 分钟逐步拉长到 60 天。")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func legend(color: Color, dashed: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 3] : []))
                .frame(width: 18, height: 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Nodes

    private var nodesCard: some View {
        let counts = vm.stageCounts
        let nodes = SpacedRepetition.nodes
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("单词停在哪个节点")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("下一次复习间隔")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            Chart {
                ForEach(nodes.indices, id: \.self) { i in
                    BarMark(x: .value("节点", nodes[i].short), y: .value("单词数", counts[i]))
                        .foregroundStyle(i >= SpacedRepetition.masteredStage ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.silver.opacity(0.55)))
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            if counts[i] > 0 {
                                Text("\(counts[i])")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.system(size: 9)).foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 130)
            .accessibilityLabel("各节点单词数")
            Text("金色节点代表已掌握：通过 7 天复习后，下一次间隔是 15 天。")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .card()
    }

    // MARK: - Upcoming

    private var upcomingCard: some View {
        let days = vm.upcomingDueCounts(days: 7)
        return VStack(alignment: .leading, spacing: 12) {
            Text("未来 7 天的复习量")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Chart {
                ForEach(days, id: \.day) { item in
                    BarMark(x: .value("日期", MemoryFormat.dayLabel(item.day, today: vm.today)), y: .value("单词数", item.count))
                        .foregroundStyle(item.day == vm.today ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.silver.opacity(0.45)))
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            if item.count > 0 {
                                Text("\(item.count)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption2).foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 120)
            .accessibilityLabel("未来 7 天每天的复习单词数")
        }
        .card()
    }

    // MARK: - Weak words

    @ViewBuilder
    private var weakWordsCard: some View {
        let ranked = vm.learnedWords
            .map { ($0, vm.retention(for: $0)) }
            .sorted { $0.1 < $1.1 }
            .prefix(8)
        if !ranked.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("最容易忘的词")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.bottom, 6)
                ForEach(Array(ranked), id: \.0.wordKey) { record, value in
                    Button { selected = record } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.word)
                                    .font(Theme.wordFont(18))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(GameRules.shortMeaning(record.meaning))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(MemoryFormat.percent(value))
                                    .font(Theme.number(.subheadline))
                                    .foregroundStyle(RetentionBar.color(value))
                                RetentionBar(value: value)
                                    .frame(width: 64)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(record.word)，记忆保持率 \(MemoryFormat.percent(value))")
                }
            }
            .card()
        }
    }
}

// MARK: - Forgetting curve chart

/// Ebbinghaus' curve without review vs. the review plan's saw-tooth, on a log time axis
/// (5 minutes and 30 days both need room).
struct ForgettingCurveChart: View {
    private struct Point: Identifiable {
        let id: Int
        let series: String
        let x: Double
        let y: Double
    }

    static let plan = "按节点复习"
    static let none = "学完不复习"
    private static let horizon = 30.0 * 1440 // minutes

    /// Log-ish axis: 0 → 0, 5 min ≈ 0.3, 30 days ≈ 3.9.
    static func axis(_ minutes: Double) -> Double { log10(1 + minutes / 5) }

    /// Review times in minutes, following the node gaps (day-long gaps counted as whole days).
    static let reviewTimes: [Double] = {
        var times: [Double] = [0]
        var t = 0.0
        for node in SpacedRepetition.nodes {
            t += node.interval / 60
            if t > horizon { break }
            times.append(t)
        }
        return times
    }()

    private static let points: [Point] = {
        var points: [Point] = []
        var id = 0
        // Without review.
        points.append(Point(id: id, series: none, x: 0, y: 1)); id += 1
        for i in 0...60 {
            let minutes = pow(10, 4.64 * Double(i) / 60) // 1 min … 30 days
            points.append(Point(id: id, series: none, x: axis(minutes), y: SpacedRepetition.ebbinghausRetention(minutes: minutes)))
            id += 1
        }
        // Review plan: decay to 80% within each gap, then back to 100%.
        let times = reviewTimes + [horizon]
        for k in 0..<(times.count - 1) where times[k + 1] > times[k] {
            let start = times[k], end = times[k + 1]
            let gap = SpacedRepetition.nodes[min(k, SpacedRepetition.maxStage)].interval / 60
            for i in 0...14 {
                let m = start + (end - start) * Double(i) / 14
                points.append(Point(id: id, series: plan, x: axis(m), y: pow(SpacedRepetition.dueRetention, (m - start) / gap)))
                id += 1
            }
        }
        return points
    }()

    var body: some View {
        Chart {
            ForEach(Self.points) { p in
                LineMark(x: .value("时间", p.x), y: .value("记忆保持率", p.y), series: .value("曲线", p.series))
                    .foregroundStyle(p.series == Self.plan ? Theme.gold : Theme.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: p.series == Self.plan ? 2 : 1.5, dash: p.series == Self.plan ? [] : [4, 4]))
            }
            ForEach(Array(Self.reviewTimes.dropFirst().enumerated()), id: \.offset) { _, t in
                PointMark(x: .value("时间", Self.axis(t)), y: .value("记忆保持率", 1.0))
                    .foregroundStyle(Theme.gold)
                    .symbolSize(18)
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: 0...(Self.axis(Self.horizon) + 0.12))
        .chartYScale(domain: 0...1.05)
        .chartXAxis {
            AxisMarks(values: [5.0, 60, 1440, 7 * 1440, 30 * 1440].map(Self.axis)) { value in
                AxisGridLine().foregroundStyle(Theme.stroke)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Self.label(forAxis: v)).font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.5, 1.0]) { value in
                AxisGridLine().foregroundStyle(Theme.stroke)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(MemoryFormat.percent(v)).font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("遗忘曲线对比：学完不复习，1 天后约剩三成；按节点复习，保持率始终在 80% 以上")
    }

    private static func label(forAxis v: Double) -> String {
        let minutes = (pow(10, v) - 1) * 5
        switch minutes {
        case ..<10: return "5分"
        case ..<100: return "1时"
        case ..<2000: return "1天"
        case ..<20000: return "7天"
        default: return "30天"
        }
    }
}
