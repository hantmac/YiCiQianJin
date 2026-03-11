import SwiftUI

struct CheckInSuccessView: View {
    let streakDays: Int
    let totalWords: Int
    let onClose: () -> Void

    private let encouragements = [
        "坚持就是胜利，虽然每天只有一个词...",
        "积少成多，一年也能背365个词呢！",
        "慢慢来，比较快。",
        "今天的你比昨天多认识了一个词！",
        "罗马不是一天建成的，单词也不是。",
        "恭喜你又完成了今天的学习任务！",
        "一词千金，你今天又赚了！",
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 60))

                Text("打卡成功！")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text(encouragements.randomElement()!)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    VStack {
                        Text("\(streakDays)")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        Text("连续天数")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding()
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack {
                        Text("\(totalWords)")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        Text("累计单词")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding()
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onClose) {
                    Text("好的")
                        .font(.headline)
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(32)
            .background(
                LinearGradient(
                    colors: [.purple, .indigo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
        }
    }
}
