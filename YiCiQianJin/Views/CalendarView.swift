import SwiftUI

struct CalendarPageView: View {
    @Bindable var vm: StudyViewModel
    @State private var displayedMonth: Date = Date()

    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Button {
                        vm.currentPage = .home
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Text("学习日历")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("返回").opacity(0)
                }

                // Stats
                HStack(spacing: 12) {
                    miniStat(value: vm.streakDays, label: "连续打卡", icon: "flame.fill", color: .orange)
                    miniStat(value: vm.totalWords, label: "已学单词", icon: "book.fill", color: .cyan)
                    miniStat(value: vm.studyDates.count, label: "学习天数", icon: "calendar", color: .green)
                }

                // Calendar
                calendarSection

                // History
                historySection
            }
            .padding()
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        let year = comps.year!
        let month = comps.month!
        let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count

        let todayComps = cal.dateComponents([.year, .month, .day], from: Date())
        let isCurrentMonthView = (year == todayComps.year! && month == todayComps.month!)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return VStack(spacing: 14) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth)!
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08))
                        .clipShape(Circle())
                }

                Spacer()
                Text(monthTitle(year: year, month: month))
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth)!
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(isCurrentMonthView ? .white.opacity(0.15) : .white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .disabled(isCurrentMonthView)
            }

            // Single grid: weekday headers + day cells
            let cells: [CalendarCell] = {
                var result: [CalendarCell] = []
                // Empty cells before first day (use negative IDs to avoid collision)
                for i in 0..<firstWeekday {
                    result.append(CalendarCell(id: -(i + 1), day: 0, hasStudy: false, isToday: false, isFuture: false))
                }
                // Day cells
                for d in 1...daysInMonth {
                    let dateStr = formatter.string(from: cal.date(from: DateComponents(year: year, month: month, day: d))!)
                    let hasStudy = vm.studyDates[dateStr] != nil
                    let isToday = isCurrentMonthView && d == todayComps.day!
                    let isFuture = isFutureDate(year: year, month: month, day: d, todayComps: todayComps)
                    result.append(CalendarCell(id: d, day: d, hasStudy: hasStudy, isToday: isToday, isFuture: isFuture))
                }
                return result
            }()

            LazyVGrid(columns: columns, spacing: 8) {
                // Weekday headers
                ForEach(weekDays, id: \.self) { d in
                    Text(d)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(height: 30)
                }

                // Day cells (single ForEach, unique IDs)
                ForEach(cells) { cell in
                    if cell.day == 0 {
                        Color.clear.frame(height: 44)
                    } else {
                        dayCellView(day: cell.day, hasStudy: cell.hasStudy, isToday: cell.isToday, isFuture: cell.isFuture)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func dayCellView(day: Int, hasStudy: Bool, isToday: Bool, isFuture: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack {
                if hasStudy {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                }
                if isToday {
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                }
                Text("\(day)")
                    .font(.subheadline.weight(hasStudy ? .bold : .regular))
                    .foregroundStyle(
                        isFuture ? .white.opacity(0.15) :
                        hasStudy ? .white : .white.opacity(0.6)
                    )
            }
            .frame(width: 34, height: 34)

            // Check-in indicator
            if hasStudy {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
            } else {
                Color.clear.frame(width: 8, height: 8)
            }
        }
        .frame(height: 44)
    }

    // MARK: - History

    private var historySection: some View {
        let grouped = Dictionary(grouping: vm.state.studyRecords, by: { $0.date })
        let sortedDates = grouped.keys.sorted(by: >)

        return VStack(alignment: .leading, spacing: 14) {
            Text("学习记录")
                .font(.headline)
                .foregroundStyle(.white)

            if sortedDates.isEmpty {
                Text("还没有学习记录")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(sortedDates.prefix(15), id: \.self) { date in
                    let records = grouped[date]!
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text(formatDateHeader(date))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text("\(records.count)个单词")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        FlowLayout(spacing: 6) {
                            ForEach(records) { record in
                                Text(record.word)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Helpers

    private func monthTitle(year: Int, month: Int) -> String {
        "\(year)年\(month)月"
    }

    private func isFutureDate(year: Int, month: Int, day: Int, todayComps: DateComponents) -> Bool {
        let ty = todayComps.year!
        let tm = todayComps.month!
        let td = todayComps.day!
        if year != ty { return year > ty }
        if month != tm { return month > tm }
        return day > td
    }

    private func formatDateHeader(_ dateStr: String) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        let todayStr = f.string(from: Date())
        if dateStr == todayStr { return "今天" }
        let yesterdayStr = f.string(from: cal.date(byAdding: .day, value: -1, to: Date())!)
        if dateStr == yesterdayStr { return "昨天" }
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    private func miniStat(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - CalendarCell

private struct CalendarCell: Identifiable {
    let id: Int
    let day: Int
    let hasStudy: Bool
    let isToday: Bool
    let isFuture: Bool
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
