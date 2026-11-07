import SwiftUI

struct CalendarPageView: View {
    @Bindable var vm: StudyViewModel
    @State private var displayedMonth = Date()
    @State private var selectedDay: String = DayKey.today()

    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        AdaptiveSplit {
            ScrollView {
                VStack(spacing: 16) {
                    statsRow
                    calendarSection
                }
                .padding()
            }
            .scrollIndicators(.hidden)
        } secondary: {
            ScrollView {
                dayDetail.padding()
            }
            .scrollIndicators(.hidden)
        } compact: {
            ScrollView {
                VStack(spacing: 16) {
                    statsRow
                    calendarSection
                    dayDetail
                }
                .padding()
                .readableWidth()
            }
            .scrollIndicators(.hidden)
        }
        .pageChrome("学习日历") { vm.go(.home) }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            miniStat(value: vm.stats.currentStreak, label: "当前连续", icon: "flame.fill", color: Theme.flame)
            miniStat(value: vm.stats.longestStreak, label: "最长连续", icon: "trophy.fill", color: Theme.gold)
            miniStat(value: vm.stats.studyDays, label: "累计天数", icon: "calendar", color: Theme.correct)
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        let firstOfMonth = cal.date(from: comps) ?? Date()
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let isCurrentMonth = cal.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
        let dates = vm.studyDates
        let keys = (1...daysInMonth).map { d in DayKey.string(from: cal.date(byAdding: .day, value: d - 1, to: firstOfMonth)!) }
        let studiedThisMonth = keys.filter { dates[$0] != nil }.count

        return VStack(spacing: 14) {
            HStack {
                monthButton("chevron.left", label: "上个月", disabled: false) { shiftMonth(-1) }
                Spacer()
                VStack(spacing: 2) {
                    Text(verbatim: "\(comps.year ?? 0)年\(comps.month ?? 0)月")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("本月打卡 \(studiedThisMonth) 天")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                monthButton("chevron.right", label: "下个月", disabled: isCurrentMonth) { shiftMonth(1) }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekDays, id: \.self) { d in
                    Text(d)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(height: 24)
                }
                ForEach(0..<firstWeekday, id: \.self) { i in
                    Color.clear.frame(height: 40).id("empty-\(i)")
                }
                ForEach(Array(keys.enumerated()), id: \.element) { i, key in
                    dayCell(day: i + 1, key: key, count: dates[key]?.count ?? 0)
                }
            }
        }
        .card(padding: 16, radius: 24)
    }

    private func monthButton(_ symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(disabled ? 0.25 : 0.9))
                .frame(width: 36, height: 36)
                .background(Theme.surface, in: Circle())
        }
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func shiftMonth(_ value: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        }
    }

    private func dayCell(day: Int, key: String, count: Int) -> some View {
        let isToday = key == vm.today
        let isFuture = DayKey.distance(from: vm.today, to: key) > 0
        let isSelected = key == selectedDay
        // Heat: one word → gold, several (Pro) → deeper gold.
        let heat: Color = count > 1 ? Theme.goldDeep : Theme.gold

        return Button {
            withAnimation(.spring(duration: 0.25)) { selectedDay = key }
        } label: {
            Text("\(day)")
                .font(.subheadline.weight(count > 0 ? .bold : .regular))
                .foregroundStyle(count > 0 ? Theme.onGold : (isFuture ? Color.white.opacity(0.25) : Theme.textSecondary))
                .frame(width: 38, height: 38)
                .background {
                    if count > 0 {
                        Circle().fill(heat)
                    }
                }
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(.white, lineWidth: 2)
                    } else if isToday {
                        Circle().strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
                .frame(height: 40)
        }
        .buttonStyle(PressableStyle())
        .disabled(isFuture)
        .accessibilityLabel("\(day) 日\(isToday ? "，今天" : "")，\(count > 0 ? "学习了 \(count) 个词" : "未学习")")
    }

    // MARK: - Day detail

    private var dayDetail: some View {
        let records = (vm.studyDates[selectedDay] ?? []).uniqueWords()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(formatDateHeader(selectedDay))
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !records.isEmpty {
                    Label("\(records.count) 个词", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.correct)
                }
            }
            if records.isEmpty {
                Text(selectedDay == vm.today ? "今天还没有学习，去背今天的一词吧" : "这一天没有学习记录")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(records) { record in
                    HStack(spacing: 12) {
                        WordThumbnail(word: record.word, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.word)
                                .font(Theme.wordFont(20))
                                .foregroundStyle(Theme.textPrimary)
                            Text(record.meaning)
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        SpeakButton(text: record.word, size: 34)
                    }
                    .card(padding: 12, radius: 16)
                }
            }
        }
        .card()
    }

    private func formatDateHeader(_ key: String) -> String {
        if key == vm.today { return "今天" }
        if key == DayKey.adding(-1, to: vm.today) { return "昨天" }
        guard let date = DayKey.date(from: key) else { return key }
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    private func miniStat(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(value)")
                .font(Theme.number(.title2))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
