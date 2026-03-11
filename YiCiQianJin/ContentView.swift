import SwiftUI

struct ContentView: View {
    @State private var vm = StudyViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.4, green: 0.49, blue: 0.92),
                         Color(red: 0.46, green: 0.29, blue: 0.64)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                switch vm.currentPage {
                case .bookSelect:
                    BookSelectView(vm: vm)

                case .home:
                    HomeView(vm: vm)

                case .study:
                    if let word = vm.currentWord {
                        StudyView(word: word) {
                            vm.markWordStudied()
                        }
                    }

                case .quiz:
                    QuizView(
                        wordsToQuiz: vm.yesterdayWords,
                        onPass: { vm.quizPassed() },
                        onFail: { vm.quizFailed($0) },
                        onRecord: { vm.recordQuizResult(word: $0, correct: $1) }
                    )

                case .reviewFailed:
                    if let record = vm.failedRecord {
                        reviewFailedView(record: record)
                    }

                case .bookComplete:
                    bookCompleteView

                case .calendar:
                    CalendarPageView(vm: vm)

                case .premium:
                    PremiumView(vm: vm)
                }
            }

            if vm.showCheckIn {
                CheckInSuccessView(
                    streakDays: vm.streakDays,
                    totalWords: vm.totalWords,
                    onClose: { vm.closeCheckIn() }
                )
            }
        }
    }

    private func reviewFailedView(record: StudyRecord) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("😤")
                    .font(.system(size: 50))
                Text("考试没通过，继续复习这个词")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                Text(record.word)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                Text(record.meaning)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text("记住了再点下面的按钮，明天还会考你！")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.4))
                Button {
                    vm.reviewDone()
                } label: {
                    Text("这次真的记住了")
                        .font(.headline)
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal)
            Spacer()
        }
    }

    private var bookCompleteView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("🎊")
                    .font(.system(size: 60))
                Text("恭喜你！")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("你已经背完了这本单词书的所有单词！")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Button {
                    vm.currentPage = .bookSelect
                } label: {
                    Text("换一本单词书")
                        .font(.headline)
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal)
            Spacer()
        }
    }
}
