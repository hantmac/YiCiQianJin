import SwiftUI

struct CalendarPageView: View {
    @Bindable var vm: StudyViewModel

    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Back button
                HStack {
                    Button {
                        vm.currentPage = .home
                    } label: {
                        Label("返回", systemImage: "chevron.left")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }

                // Stats
                HStack(spacing: 12) {
                    miniStat(value: vm.streakDays, label: "连续打卡")
                    miniStat(value: vm.totalWords, label: "已学单词")
                    miniStat(value: vm.studyDates.count, label: "学习天数")
                }

                // Calendar
                calendarSection

                // History
                historySection
            }
            .padding()
        }
    }

    private var calendarSection: some View {
        let today = Date()
        let cal = Calendar.current
        let year = cal.component(.year, from: today)
        let month = cal.component(.month, from: today)
        let day = cal.component(.day, from: today)
        let firstWeekday = cal.component(.weekday, from: cal.date(from: DateComponents(year: year, month: month, day: 1))!) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: today)!.count

        return VStack(spacing: 12) {
            Text("\(year)年\(month)月")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekDays, id: \.self) { d in
                    Text(d)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }

                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Text("")
                }

                ForEach(1...daysInMonth, id: \.self) { d in
                    let dateStr = String(format: "%04d-%02d-%02d", year, month, d)
                    let hasStudy = vm.studyDates[dateStr] != nil
                    let isToday = d == day

                    Text("\(d)")
                        .font(.caption)
                        .fontWeight(hasStudy ? .bold : .regular)
                        .foregroundStyle(hasStudy ? .green : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(hasStudy ? Color.green.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isToday ? .white.opacity(0.4) : .clear, lineWidth: 2)
                        )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var historySection: some View {
        let allRecords = vm.state.studyRecords.sorted { $0.date > $1.date }

        return VStack(alignment: .leading, spacing: 12) {
            Text("学习记录")
                .font(.headline)
                .foregroundStyle(.white)

            if allRecords.isEmpty {
                Text("还没有学习记录")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(allRecords.prefix(30)) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.word)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(record.meaning)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text(record.date)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal)
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

    private func miniStat(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
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
