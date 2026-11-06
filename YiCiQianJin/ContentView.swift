import SwiftUI

struct ContentView: View {
    @State private var vm = StudyViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppBackground()

            // A system NavigationStack hosts each page's toolbar, so iPhone Duo can lay
            // Back/Close out vertically on the outer display.
            NavigationStack {
                page
                    .id(vm.currentPage)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                        removal: .opacity
                    ))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background { AppBackground() }
            }

            if let toast = vm.toast {
                VStack {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.onGold)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Theme.goldGradient, in: Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                        .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
            }

            if let celebration = vm.celebration {
                CheckInSuccessView(celebration: celebration, stats: vm.stats, level: vm.level) {
                    withAnimation(.easeInOut(duration: 0.25)) { vm.closeCelebration() }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: vm.currentPage)
        .animation(.easeInOut(duration: 0.25), value: vm.celebration?.id)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { vm.refreshDay() }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch vm.currentPage {
        case .bookSelect:
            BookSelectView(vm: vm)
        case .home:
            HomeView(vm: vm)
        case .study:
            if let word = vm.currentWord {
                StudyView(vm: vm, word: word)
                    .id(word.word) // fresh reveal/spelling state for each new word
            } else {
                HomeView(vm: vm)
            }
        case .exam:
            QuizView(vm: vm, mode: .exam, records: vm.examWords)
        case .review:
            QuizView(vm: vm, mode: .review, records: Array(vm.dueReviews.prefix(StudyViewModel.reviewBatch)))
        case .bookComplete:
            bookCompleteView
        case .calendar:
            CalendarPageView(vm: vm)
        case .premium:
            PremiumView(vm: vm)
        case .library:
            WordLibraryView(vm: vm)
        case .achievements:
            AchievementsView(vm: vm)
        case .settings:
            SettingsView(vm: vm)
        }
    }

    private var bookCompleteView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.goldGradient)
                Text("整本词书已学完！")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("「\(vm.currentBook?.name ?? "")」的每一个单词都已收入你的词库。\n温故复习会继续帮你巩固它们。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("挑战下一本词书") { vm.go(.bookSelect) }
                    .buttonStyle(GoldButtonStyle())
                    .padding(.top, 6)
            }
            .card(padding: 28, radius: 28)
            .padding(.horizontal)
            .readableWidth(520)
            Spacer()
        }
        .pageChrome("") { vm.go(.home) }
    }
}
