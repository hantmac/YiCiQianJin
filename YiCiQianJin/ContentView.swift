import SwiftUI

struct ContentView: View {
    @State private var vm = StudyViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppBackground()

            Group {
                if vm.currentPage == .home {
                    tabs
                } else {
                    // A system NavigationStack hosts each page's toolbar, so iPhone Duo can lay
                    // Back/Close out vertically on the outer display.
                    NavigationStack {
                        page
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background { AppBackground() }
                    }
                }
            }
            .id(vm.currentPage)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.97)),
                removal: .opacity
            ))

            if let toast = vm.toast {
                VStack {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.onGold)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Theme.goldGradient, in: Capsule())
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                        .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
            }

            if let celebration = vm.celebration {
                CheckInSuccessView(celebration: celebration, stats: vm.stats, level: vm.level,
                                   actionTitle: vm.celebrationActionTitle) {
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
        .task {
            // Review due times are minutes apart on the first day; keep due lists current.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                vm.tick()
            }
        }
    }

    /// 背单词 / 词库 / 发现 / 我的. Learning flows and secondary pages cover the tab bar.
    private var tabs: some View {
        // tabItem/tag rather than `Tab` keeps iOS 17 support.
        TabView(selection: $vm.tab) {
            tabRoot { HomeView(vm: vm) }
                .tabItem { Label("背单词", systemImage: "book.pages") }
                .tag(AppTab.learn)
            tabRoot { WordLibraryView(vm: vm) }
                .tabItem { Label("词库", systemImage: "books.vertical") }
                .tag(AppTab.library)
            tabRoot { DiscoverView(vm: vm) }
                .tabItem { Label("发现", systemImage: "sparkles") }
                .tag(AppTab.discover)
            tabRoot { MeView(vm: vm) }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(AppTab.me)
        }
        .tint(Theme.gold)
    }

    private func tabRoot<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { AppBackground() }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch vm.currentPage {
        case .bookSelect:
            BookSelectView(vm: vm)
        case .home, .library, .discover, .me:
            EmptyView() // shown by `tabs`
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
        case .achievements:
            AchievementsView(vm: vm)
        case .settings:
            SettingsView(vm: vm)
        case .memory:
            MemoryCurveView(vm: vm)
        case .collection:
            CollectionView(vm: vm)
        case .blitz:
            BlitzGameView(vm: vm)
        case .match:
            MatchGameView(vm: vm)
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
                    .foregroundStyle(Theme.textPrimary)
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
