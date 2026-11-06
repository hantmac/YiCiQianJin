import Foundation
import SwiftUI

enum AppPage: Equatable {
    case home, bookSelect, study, exam, review, bookComplete
    case calendar, premium, library, achievements, settings
}

/// A reward moment shown as an overlay (daily check-in, level up, new achievements).
struct Celebration: Identifiable {
    enum Kind { case checkIn, milestone }

    let id = UUID()
    let kind: Kind
    let xpGained: Int
    let newAchievements: [Achievement]
    let newLevel: Level?
}

@Observable
class StudyViewModel {
    private let storageKey = "yiciqianjin_state"
    static let examLimit = 20
    static let reviewBatch = 10

    var state: AppState {
        didSet {
            save()
            stats = LearningStats(state: state, today: today)
        }
    }

    private(set) var stats = LearningStats()
    private(set) var today: String = DayKey.today()

    // Navigation & transient UI
    var currentPage: AppPage = .home
    var celebration: Celebration?
    var toast: String?

    /// XP when the current exam/review session started, used to detect level-ups.
    private var sessionStartXP = 0

    let storeManager = StoreManager()

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            self.state = saved
        } else {
            self.state = AppState()
        }
        stats = LearningStats(state: state, today: today)

        // Existing users shouldn't get a burst of "new" achievements on upgrade.
        if !state.achievementsInitialized {
            state.seenAchievements = Achievement.unlocked(stats).map(\.id)
            state.achievementsInitialized = true
        }

        refreshDay()
        // Property observers don't fire during init, so persist migrations explicitly.
        stats = LearningStats(state: state, today: today)
        save()
        if state.selectedBookId == nil {
            currentPage = .bookSelect
        }

        Task { @MainActor in
            await storeManager.checkPurchased()
            if storeManager.isPurchased {
                state.isPremium = true
            }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Call when the app becomes active so a session left open overnight rolls over correctly.
    func refreshDay() {
        let now = DayKey.today()
        if now != today {
            today = now
        }
        if state.todayDate != now {
            state.todayStudied = false
            state.todayQuizPassed = false
            state.todayDate = now
        } else {
            stats = LearningStats(state: state, today: today)
        }
        syncReminders()
    }

    // MARK: - Derived

    var currentBook: WordBook? { WordData.book(state.selectedBookId) }

    var currentWord: Word? {
        guard let book = currentBook, state.currentWordIndex < book.words.count else { return nil }
        return book.words[state.currentWordIndex]
    }

    var isBookComplete: Bool {
        guard let book = currentBook else { return false }
        return state.currentWordIndex >= book.words.count
    }

    var level: Level { Level.for(xp: stats.xp) }

    var yesterdayWords: [StudyRecord] {
        let yesterday = DayKey.adding(-1, to: today)
        return state.studyRecords.filter { $0.date == yesterday }.uniqueWords()
    }

    var todayRecords: [StudyRecord] {
        state.studyRecords.filter { $0.date == today }
    }

    var hasStudiedToday: Bool { !todayRecords.isEmpty }

    var examWords: [StudyRecord] { Array(yesterdayWords.prefix(Self.examLimit)) }

    var examPending: Bool { !examWords.isEmpty && !state.todayQuizPassed }

    /// Free users must pass yesterday's exam before today's new word; Pro may skip it.
    var mustTakeExamFirst: Bool { examPending && !state.isPremium }

    var canLearnNewWord: Bool { !isBookComplete && (state.isPremium || !hasStudiedToday) }

    /// Words whose review date has arrived, excluding ones today's exam will cover anyway.
    var dueReviews: [StudyRecord] {
        let examKeys = examPending ? Set(examWords.map(\.wordKey)) : []
        return state.studyRecords.uniqueWords()
            .filter { $0.date != today && !examKeys.contains($0.wordKey) }
            .filter { SpacedRepetition.isDue(SpacedRepetition.state(for: $0, in: state.reviewStates), today: today) }
            .sorted { reviewState(for: $0).due < reviewState(for: $1).due }
    }

    func reviewState(for record: StudyRecord) -> ReviewState {
        SpacedRepetition.state(for: record, in: state.reviewStates)
    }

    func progress(for bookId: String) -> Int {
        bookId == state.selectedBookId ? state.currentWordIndex : (state.bookProgress[bookId] ?? 0)
    }

    var studyDates: [String: [StudyRecord]] {
        Dictionary(grouping: state.studyRecords, by: \.date)
    }

    /// Wrong-answer count per word, for the mistakes filter in the word library.
    var mistakeCounts: [String: Int] {
        state.quizResults.filter { !$0.correct }.reduce(into: [:]) { $0[$1.word, default: 0] += 1 }
    }

    // MARK: - Navigation

    func go(_ page: AppPage) {
        currentPage = page
    }

    func selectBook(_ bookId: String) {
        if let old = state.selectedBookId {
            state.bookProgress[old] = state.currentWordIndex
        }
        state.selectedBookId = bookId
        state.currentWordIndex = state.bookProgress[bookId] ?? 0
        currentPage = .home
    }

    func startStudy() {
        if mustTakeExamFirst {
            startExam()
        } else if isBookComplete {
            currentPage = .bookComplete
        } else if canLearnNewWord {
            currentPage = .study
        }
    }

    func startExam() {
        guard !examWords.isEmpty else { return }
        sessionStartXP = stats.xp
        currentPage = .exam
    }

    func startReview() {
        guard !dueReviews.isEmpty else { return }
        sessionStartXP = stats.xp
        currentPage = .review
    }

    // MARK: - Learning actions

    func markWordStudied() {
        guard let word = currentWord, let bookId = state.selectedBookId else { return }
        let firstToday = !hasStudiedToday
        let xpBefore = stats.xp

        let record = StudyRecord(date: today, word: word.word, meaning: word.meaning, bookId: bookId, passed: true)
        state.studyRecords.append(record)
        state.reviewStates[record.wordKey] = SpacedRepetition.initial(learnedOn: today)
        state.todayStudied = true
        state.todayDate = today
        state.currentWordIndex += 1
        state.bookProgress[bookId] = state.currentWordIndex
        syncReminders()

        let achievements = collectNewAchievements()
        let newLevel = levelUp(from: xpBefore)
        if firstToday || !achievements.isEmpty || newLevel != nil {
            // Show home underneath so the next word isn't visible behind the overlay.
            currentPage = isBookComplete ? .bookComplete : .home
            celebration = Celebration(kind: .checkIn, xpGained: stats.xp - xpBefore,
                                      newAchievements: achievements, newLevel: newLevel)
        } else {
            // Extra words for Pro users: keep the flow going instead of a modal each time.
            showToast("+\(LearningStats.Reward.newWord) 金 · 今日已学 \(todayRecords.count) 词")
            if isBookComplete { currentPage = .bookComplete }
        }
    }

    func recordAnswer(_ record: StudyRecord, correct: Bool, source: QuizSource) {
        state.quizResults.append(QuizResult(word: record.word, correct: correct, date: today,
                                            source: source, bookId: record.bookId))
        state.reviewStates[record.wordKey] = SpacedRepetition.next(after: reviewState(for: record),
                                                                  correct: correct, on: today)
    }

    /// Exam finished (failed words have already been re-studied in the summary screen).
    func finishExam() {
        state.todayQuizPassed = true
        state.todayDate = today
        showMilestoneIfNeeded()
        if canLearnNewWord {
            currentPage = isBookComplete ? .bookComplete : .study
        } else {
            currentPage = .home
        }
    }

    func finishReview() {
        showMilestoneIfNeeded()
        currentPage = .home
    }

    func closeCelebration() {
        celebration = nil
    }

    // MARK: - Rewards

    private func collectNewAchievements() -> [Achievement] {
        let seen = Set(state.seenAchievements)
        let fresh = Achievement.unlocked(stats).filter { !seen.contains($0.id) }
        if !fresh.isEmpty {
            state.seenAchievements += fresh.map(\.id)
        }
        return fresh
    }

    private func levelUp(from xpBefore: Int) -> Level? {
        let before = Level.for(xp: xpBefore)
        return level.index > before.index ? level : nil
    }

    private func showMilestoneIfNeeded() {
        let achievements = collectNewAchievements()
        let newLevel = levelUp(from: sessionStartXP)
        if !achievements.isEmpty || newLevel != nil {
            celebration = Celebration(kind: .milestone, xpGained: stats.xp - sessionStartXP,
                                      newAchievements: achievements, newLevel: newLevel)
        }
    }

    func showToast(_ message: String) {
        withAnimation(.spring(duration: 0.35)) { toast = message }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if toast == message {
                withAnimation(.easeOut(duration: 0.25)) { toast = nil }
            }
        }
    }

    // MARK: - Reminders

    /// Returns false if the user declined notification permission.
    @MainActor
    func setReminder(enabled: Bool) async -> Bool {
        if enabled {
            let granted = await ReminderScheduler.isAuthorized() ? true : await ReminderScheduler.requestAuthorization()
            state.reminderEnabled = granted
            syncReminders()
            return granted
        }
        state.reminderEnabled = false
        await ReminderScheduler.cancelAll()
        return true
    }

    func setReminderTime(hour: Int, minute: Int) {
        state.reminderHour = hour
        state.reminderMinute = minute
        syncReminders()
    }

    private func syncReminders() {
        guard state.reminderEnabled else { return }
        let hour = state.reminderHour, minute = state.reminderMinute
        let studied = hasStudiedToday, streak = stats.currentStreak
        Task {
            await ReminderScheduler.reschedule(hour: hour, minute: minute, studiedToday: studied, streak: streak)
        }
    }

    // MARK: - Premium

    func upgradeToPremium() async -> Bool {
        let success = await storeManager.purchase()
        if success {
            state.isPremium = true
            currentPage = .home
        }
        return success
    }
}
