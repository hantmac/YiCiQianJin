import SwiftUI

struct HomeView: View {
    @Bindable var vm: StudyViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Title
                VStack(spacing: 4) {
                    Text("一词千金")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("每天一个词，多了要加钱")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Stats
                HStack(spacing: 12) {
                    statCard(value: vm.streakDays, label: "连续打卡")
                    statCard(value: vm.totalWords, label: "已学单词")
                }

                // Current book
                if let book = vm.currentBook {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("当前词书")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            Text(book.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Button("更换") {
                            vm.currentPage = .bookSelect
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Main action
                if vm.hasStudiedToday && !vm.state.isPremium {
                    todayDoneView
                } else {
                    Button(action: { vm.startStudy() }) {
                        Text(vm.hasStudiedToday ? "继续背单词" : "开始今日学习")
                            .font(.title3.bold())
                            .foregroundStyle(.purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }

                // Bottom nav
                HStack(spacing: 12) {
                    Button {
                        vm.currentPage = .calendar
                    } label: {
                        Label("学习日历", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        vm.currentPage = .premium
                    } label: {
                        Label(vm.state.isPremium ? "Pro 会员" : "升级 Pro", systemImage: "crown")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var todayDoneView: some View {
        VStack(spacing: 16) {
            Text("😌")
                .font(.system(size: 50))
            Text("今天的任务完成了")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("明天再来吧，或者...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            Button {
                vm.currentPage = .premium
            } label: {
                Text("想多背？升级 Pro 👑")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func statCard(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
