import SwiftUI
import Charts

// MARK: - Formatting

enum MemoryFormat {
    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    /// "现在", "4 分钟后", "今天 21:05", "明天", "3 天后".
    static func relative(_ date: Date, from now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "现在" }
        if seconds < SpacedRepetition.hour {
            return "\(max(1, Int((seconds / 60).rounded(.up)))) 分钟后"
        }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        let dayAligned = cal.startOfDay(for: date) == date
        switch days {
        case 0: return "今天 \(time.string(from: date))"
        case 1: return dayAligned ? "明天" : "明天 \(time.string(from: date))"
        default: return "\(days) 天后"
        }
    }

    static func date(_ date: Date) -> String { monthDay.string(from: date) }

    static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    /// Day header for the next-7-days chart.
    static func dayLabel(_ key: String, today: String) -> String {
        switch DayKey.distance(from: today, to: key) {
        case 0: return "今天"
        case 1: return "明天"
        default:
            guard let date = DayKey.date(from: key) else { return key }
            let weekday = Calendar.current.component(.weekday, from: date)
            return "周" + ["日", "一", "二", "三", "四", "五", "六"][weekday - 1]
        }
    }
}

// MARK: - Sparkline

/// Saw-tooth of the review plan: each review lifts retention back up and the next decline is slower.
struct MemorySparkline: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let segments: [CGFloat] = [0.08, 0.12, 0.17, 0.25, 0.38]
            let total = segments.reduce(0, +)
            let floor = h * 0.55
            let path = Path { p in
                var x: CGFloat = 0
                p.move(to: CGPoint(x: 0, y: 2))
                for seg in segments {
                    let width = w * seg / total
                    for i in 1...12 {
                        let t = CGFloat(i) / 12
                        // Same shape as the retention model: 0.8^t within each gap.
                        let y = 2 + (1 - pow(0.8, t)) / 0.2 * (floor - 2)
                        p.addLine(to: CGPoint(x: x + width * t, y: y))
                    }
                    x += width
                    if x < w - 1 { p.addLine(to: CGPoint(x: x, y: 2)) }
                }
            }
            // The unreviewed Ebbinghaus decline, for contrast.
            let forgetting = Path { p in
                p.move(to: CGPoint(x: 0, y: 2))
                for i in 1...24 {
                    let t = CGFloat(i) / 24
                    p.addLine(to: CGPoint(x: w * t, y: 2 + (h - 4) * (1 - 1 / (1 + 6 * t))))
                }
            }
            ZStack {
                forgetting.stroke(Theme.textTertiary.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                path.stroke(Theme.goldGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Node track

/// The ten Ebbinghaus review nodes; passed nodes are gilt, the next one is ringed.
struct MemoryNodeTrack: View {
    let stage: Int
    var showLabels = true

    var body: some View {
        let nodes = SpacedRepetition.nodes
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(nodes.indices, id: \.self) { i in
                    if i > 0 {
                        Rectangle()
                            .fill(i <= stage ? Theme.gold.opacity(0.7) : Theme.track)
                            .frame(height: 2)
                    }
                    ZStack {
                        Circle()
                            .fill(i < stage ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surfaceStrong))
                        if i == stage {
                            Circle().strokeBorder(Theme.gold, lineWidth: 2)
                        } else if i >= stage {
                            Circle().strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                    }
                    .frame(width: i == stage ? 14 : 10, height: i == stage ? 14 : 10)
                }
            }
            if showLabels {
                HStack(spacing: 0) {
                    ForEach(nodes.indices, id: \.self) { i in
                        Text(nodes[i].short)
                            .font(.system(size: 9, weight: i == stage ? .bold : .regular))
                            .foregroundStyle(i == stage ? Theme.gold : Theme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("记忆节点：已通过 \(stage) 个，共 \(nodes.count) 个")
    }
}

/// Horizontal retention meter, coloured by how close the word is to being forgotten.
struct RetentionBar: View {
    let value: Double

    var body: some View {
        CapsuleBar(progress: value, height: 4, tint: AnyShapeStyle(RetentionBar.color(value)))
    }

    static func color(_ value: Double) -> Color {
        if value <= SpacedRepetition.dueRetention + 0.0001 { return Theme.flame }
        if value < 0.9 { return Theme.gold }
        return Theme.correct
    }
}

// MARK: - Word memory sheet

/// One word's place on its forgetting curve.
struct WordMemorySheet: View {
    let vm: StudyViewModel
    let record: StudyRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let state = vm.reviewState(for: record)
        let now = vm.now
        let retention = SpacedRepetition.retention(state, at: now)
        let due = SpacedRepetition.isDue(state, at: now)
        let word = WordData.word(for: record)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        WordThumbnail(word: record.word, size: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.word)
                                .font(Theme.wordFont(30))
                                .foregroundStyle(Theme.textPrimary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            if let phonetic = word?.phonetic, !phonetic.isEmpty {
                                Text(phonetic)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        Spacer(minLength: 0)
                        SpeakButton(text: record.word)
                    }
                    Text(record.meaning)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(MemoryFormat.percent(retention))
                                    .font(.system(size: 36, weight: .semibold, design: .serif))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("当前记忆保持率")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(due ? "该复习了" : MemoryFormat.relative(state.dueAt, from: now))
                                    .font(.headline)
                                    .foregroundStyle(due ? Theme.flame : Theme.textPrimary)
                                Text(due ? "已降到 80% 以下" : "下次复习 · \(MemoryFormat.date(state.dueAt))")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        WordCurveChart(state: state, now: now)
                            .frame(height: 150)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("复习节点")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        MemoryNodeTrack(stage: state.stage)
                        Text(nodeSummary(state))
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card()
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .navigationTitle("记忆详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bgTop)
    }

    private func nodeSummary(_ state: ReviewState) -> String {
        var parts = ["已通过 \(state.stage) 个节点"]
        if state.lapses > 0 { parts.append("遗忘过 \(state.lapses) 次") }
        let toMaster = SpacedRepetition.masteredStage - state.stage
        parts.append(toMaster > 0 ? "再通过 \(toMaster) 个节点成为「已掌握」" : "已掌握，间隔会继续拉长")
        return parts.joined(separator: " · ")
    }
}

/// Retention from the last review to a bit past the due time, with "now" marked.
struct WordCurveChart: View {
    let state: ReviewState
    let now: Date

    private struct Point: Identifiable {
        let id: Int
        let date: Date
        let value: Double
    }

    var body: some View {
        let start = state.anchor
        let gap = max(state.dueAt.timeIntervalSince(start), SpacedRepetition.minute)
        let end = max(state.dueAt, now).addingTimeInterval(gap * 0.5)
        let span = end.timeIntervalSince(start)
        let points = (0...40).map { i -> Point in
            let date = start.addingTimeInterval(span * Double(i) / 40)
            return Point(id: i, date: date, value: SpacedRepetition.retention(state, at: date))
        }
        let current = SpacedRepetition.retention(state, at: now)

        Chart {
            ForEach(points) { p in
                AreaMark(x: .value("时间", p.date), yStart: .value("下限", 0.4), yEnd: .value("保持率", max(p.value, 0.4)))
                    .foregroundStyle(LinearGradient(colors: [Theme.gold.opacity(0.22), Theme.gold.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("时间", p.date), y: .value("保持率", max(p.value, 0.4)))
                    .foregroundStyle(Theme.gold)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("复习线", SpacedRepetition.dueRetention))
                .foregroundStyle(Theme.textTertiary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, alignment: .leading) {
                    Text("80% 复习线")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            PointMark(x: .value("时间", now), y: .value("保持率", max(current, 0.4)))
                .foregroundStyle(Theme.textPrimary)
                .symbolSize(60)
                .annotation(position: .top) {
                    Text("现在")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                }
        }
        .chartYScale(domain: 0.4...1.02)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0.4, 0.6, 0.8, 1.0]) { value in
                AxisGridLine().foregroundStyle(Theme.stroke)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(MemoryFormat.percent(v)).font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: span > 2 * SpacedRepetition.day ? .dateTime.month().day() : .dateTime.hour().minute())
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("遗忘曲线，当前保持率 \(MemoryFormat.percent(current))")
    }
}
