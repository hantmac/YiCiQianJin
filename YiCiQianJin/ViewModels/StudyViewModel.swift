import Foundation
import SwiftUI

enum AppPage: Equatable {
    /// The tab bar; which tab shows is `StudyViewModel.tab`.
    case home
    case bookSelect, study, exam, review, bookComplete
    case calendar, premium, library, achievements, settings
    case memory, collection, discover, me, blitz, match
}

enum AppTab: Hashable {
    case learn, library, discover, me
}

/// Today's learning, in the order the flow runs it.
struct TodayPlan: Equatable {
    var exam = 0
    var newWords = 0
    var review = 0

    var total: Int { exam + newWords + review }

    /// Rough minutes: ~8 s per question, ~1 min per new word.
    var minutes: Int { max(1, Int((Double(exam + review) * 8 / 60 + Double(newWords)).rounded(.up))) }
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
    /// Clock for review due times; refreshed by `tick()` so due lists update while the app is open.
    private(set) var now = Date()

    // Navigation & transient UI
    var currentPage: AppPage = .home
    var tab: AppTab = .learn
    var celebration: Celebration?
    var toast: String?

    /// XP when the current exam/review session started, used to detect level-ups.
    private var sessionStartXP = 0
    /// Step to open once the check-in overlay is closed.
    private var pendingStep: AppPage?

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
        #if DEBUG
        // Screenshots / UI tests can open a page directly: -UITestPage memory
        if let page = UserDefaults.standard.string(forKey: "UITestPage") {
            let pages: [String: AppPage] = ["memory": .memory, "collection": .collection, "discover": .discover, "me": .me,
                                            "blitz": .blitz, "match": .match, "library": .library,
                                            "achievements": .achievements, "calendar": .calendar,
                                            "settings": .settings, "study": .study, "review": .review]
            if let target = pages[page] { go(target) }
        }
        #endif

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
        now = Date()
        let day = DayKey.today(now)
        if day != today {
            today = day
        }
        if state.todayDate != day {
            state.todayStudied = false
            state.todayQuizPassed = false
            state.todayDate = day
        } else {
            stats = LearningStats(state: state, today: today)
        }
        syncReminders()
    }

    /// Advances the review clock; rolls the day over when midnight passed.
    func tick() {
        if DayKey.today() != today {
            refreshDay()
        } else {
            now = Date()
        }
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

    var learnedWords: [StudyRecord] { state.studyRecords.uniqueWords() }

    /// Words whose review time has arrived, excluding ones today's exam will cover anyway.
    var dueReviews: [StudyRecord] {
        let examKeys = examPending ? Set(examWords.map(\.wordKey)) : []
        return learnedWords
            .filter { !examKeys.contains($0.wordKey) }
            .map { ($0, reviewState(for: $0)) }
            .filter { SpacedRepetition.isDue($0.1, at: now) }
            .sorted { $0.1.dueAt < $1.1.dueAt }
            .map(\.0)
    }

    func reviewState(for record: StudyRecord) -> ReviewState {
        SpacedRepetition.state(for: record, in: state.reviewStates)
    }

    func retention(for record: StudyRecord) -> Double {
        SpacedRepetition.retention(reviewState(for: record), at: now)
    }

    /// Mean estimated retention over all learned words, nil before the first word.
    var averageRetention: Double? {
        let words = learnedWords
        guard !words.isEmpty else { return nil }
        return words.reduce(0) { $0 + retention(for: $1) } / Double(words.count)
    }

    /// The next word to fall due (not yet due), for "5 分钟后复习 harbour".
    var nextUpcomingReview: (record: StudyRecord, state: ReviewState)? {
        learnedWords
            .map { ($0, reviewState(for: $0)) }
            .filter { $0.1.dueAt > now }
            .min { $0.1.dueAt < $1.1.dueAt }
            .map { (record: $0.0, state: $0.1) }
    }

    /// Words per memory node (index = stage).
    var stageCounts: [Int] {
        var counts = Array(repeating: 0, count: SpacedRepetition.nodes.count)
        for record in learnedWords { counts[SpacedRepetition.clamp(reviewState(for: record).stage)] += 1 }
        return counts
    }

    /// Reviews falling due on each of the next `days` days; overdue words count for today.
    func upcomingDueCounts(days: Int = 7) -> [(day: String, count: Int)] {
        var counts: [String: Int] = [:]
        for record in learnedWords {
            let due = reviewState(for: record).due
            let key = DayKey.distance(from: today, to: due) < 0 ? today : due
            counts[key, default: 0] += 1
        }
        return (0..<days).map { offset in
            let key = DayKey.adding(offset, to: today)
            return (key, counts[key] ?? 0)
        }
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
        // Tab roots live inside the tab bar.
        switch page {
        case .library: tab = .library; currentPage = .home
        case .discover: tab = .discover; currentPage = .home
        case .me: tab = .me; currentPage = .home
        default: currentPage = page
        }
    }

    // MARK: - Today's flow

    /// Exam → new word → review. Each step opens the next one when it ends.
    var todayPlan: TodayPlan {
        TodayPlan(exam: examPending ? examWords.count : 0,
                  newWords: (canLearnNewWord && !hasStudiedToday) ? 1 : 0,
                  review: min(dueReviews.count, Self.reviewBatch))
    }

    /// The next unfinished step of today's flow, nil when everything is done.
    var nextStep: AppPage? {
        if examPending { return .exam }
        if canLearnNewWord && !hasStudiedToday { return .study }
        if !dueReviews.isEmpty { return .review }
        return nil
    }

    /// Label for a button that opens `nextStep`.
    var nextStepTitle: String? {
        switch nextStep {
        case .exam: return "昨日考试 \(examWords.count) 词"
        case .study: return "学习今日新词"
        case .review: return "温故复习 \(min(dueReviews.count, Self.reviewBatch)) 词"
        default: return nil
        }
    }

    /// Home's one button.
    func startToday() {
        switch nextStep {
        case .exam: startExam()
        case .study: startStudy()
        case .review: startReview()
        default: break
        }
    }

    /// Ends a step: opens the next one, or returns to the learn tab.
    private func continueFlow() {
        tab = .learn
        switch nextStep {
        case .exam: startExam()
        case .study: currentPage = isBookComplete ? .bookComplete : .study
        case .review: startReview()
        default: currentPage = .home
        }
    }

    func selectBook(_ bookId: String) {
        if let old = state.selectedBookId {
            state.bookProgress[old] = state.currentWordIndex
        }
        state.selectedBookId = bookId
        state.currentWordIndex = state.bookProgress[bookId] ?? 0
        tab = .learn
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
        state.reviewStates[record.wordKey] = SpacedRepetition.initial(learnedAt: Date())
        state.todayStudied = true
        state.todayDate = today
        state.currentWordIndex += 1
        state.bookProgress[bookId] = state.currentWordIndex
        syncReminders()

        let achievements = collectNewAchievements()
        let newLevel = levelUp(from: xpBefore)
        if firstToday || !achievements.isEmpty || newLevel != nil {
            // Show home underneath so the next word isn't visible behind the overlay;
            // the flow continues once the overlay closes.
            tab = .learn
            currentPage = isBookComplete ? .bookComplete : .home
            pendingStep = isBookComplete ? nil : nextStep
            celebration = Celebration(kind: .checkIn, xpGained: stats.xp - xpBefore,
                                      newAchievements: achievements, newLevel: newLevel)
        } else {
            // Extra words for Pro users: keep the flow going instead of a modal each time.
            showToast("+\(LearningStats.Reward.newWord) 金 · 今日已学 \(todayRecords.count) 词")
            if isBookComplete { currentPage = .bookComplete }
        }
    }

    /// Records a quiz answer and reschedules the word. Returns the schedule from before the
    /// answer so the grade can still be changed (e.g. "有点模糊") with `regrade`.
    @discardableResult
    func recordAnswer(_ record: StudyRecord, correct: Bool, source: QuizSource,
                      grade: ReviewGrade? = nil) -> ReviewState {
        now = Date()
        let previous = reviewState(for: record)
        state.quizResults.append(QuizResult(word: record.word, correct: correct, date: today,
                                            source: source, bookId: record.bookId))
        state.reviewStates[record.wordKey] = SpacedRepetition.next(after: previous,
                                                                  grade: grade ?? (correct ? .remembered : .forgot),
                                                                  at: now)
        syncReminders()
        return previous
    }

    func regrade(_ record: StudyRecord, from previous: ReviewState, grade: ReviewGrade) {
        state.reviewStates[record.wordKey] = SpacedRepetition.next(after: previous, grade: grade, at: now)
        syncReminders()
    }

    /// Exam finished (failed words have already been re-studied in the summary screen).
    func finishExam() {
        state.todayQuizPassed = true
        state.todayDate = today
        showMilestoneIfNeeded()
        continueFlow()
    }

    func finishReview() {
        showMilestoneIfNeeded()
        tab = .learn
        currentPage = .home
    }

    // MARK: - Games

    func canPlay(_ kind: GameKind) -> Bool { learnedWords.count >= kind.minimumWords }

    func startGame(_ kind: GameKind) {
        guard canPlay(kind) else { return }
        sessionStartXP = stats.xp
        currentPage = kind == .blitz ? .blitz : .match
    }

    /// Saves a finished game; returns the coins it earned (games pay out up to a daily cap).
    @discardableResult
    func recordGame(_ kind: GameKind, score: Int, correct: Int, total: Int) -> Int {
        let before = stats.xp
        state.gameRecords.append(GameRecord(date: today, kind: kind, score: score, correct: correct, total: total))
        return stats.xp - before
    }

    func finishGame() {
        showMilestoneIfNeeded()
        go(.discover)
    }

    func closeCelebration() {
        celebration = nil
        if let step = pendingStep {
            pendingStep = nil
            switch step {
            case .exam: startExam()
            case .review: startReview()
            case .study: currentPage = .study
            default: break
            }
        }
    }

    /// Button title on the check-in overlay.
    var celebrationActionTitle: String {
        switch pendingStep {
        case .review: return "收下千金，去复习"
        case .exam: return "收下千金，去考试"
        default: return "收下千金"
        }
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

    /// Returns false if the user declined notification permission.
    @MainActor
    func setReviewAlerts(enabled: Bool) async -> Bool {
        if enabled {
            let granted = await ReminderScheduler.isAuthorized() ? true : await ReminderScheduler.requestAuthorization()
            state.reviewAlertsEnabled = granted
            syncReminders()
            return granted
        }
        state.reviewAlertsEnabled = false
        await ReminderScheduler.cancelReviewAlerts()
        return true
    }

    private func syncReminders() {
        if state.reminderEnabled {
            let hour = state.reminderHour, minute = state.reminderMinute
            let studied = hasStudiedToday, streak = stats.currentStreak
            Task {
                await ReminderScheduler.reschedule(hour: hour, minute: minute, studiedToday: studied, streak: streak)
            }
        }
        if state.reviewAlertsEnabled {
            let alerts = reviewAlertPlan()
            Task { await ReminderScheduler.rescheduleReviewAlerts(alerts) }
        }
    }

    /// Upcoming review times for the next three days, merged so close due times share one alert.
    func reviewAlertPlan(limit: Int = 8) -> [ReminderScheduler.ReviewAlert] {
        let cal = Calendar.current
        let current = Date()
        let horizon = current.addingTimeInterval(3 * SpacedRepetition.day)
        var items: [(fire: Date, word: String)] = []
        for record in learnedWords {
            let due = reviewState(for: record).dueAt
            guard due > current, due < horizon else { continue }
            var fire = due
            if cal.startOfDay(for: due) == due {
                // Day-long gaps: the daily reminder already covers that day.
                if state.reminderEnabled { continue }
                fire = cal.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
            }
            items.append((ReminderScheduler.outsideQuietHours(fire), record.word))
        }
        items.sort { $0.fire < $1.fire }

        var alerts: [ReminderScheduler.ReviewAlert] = []
        for item in items {
            if let last = alerts.last, let first = last.firstDue,
               item.fire.timeIntervalSince(first) <= 10 * SpacedRepetition.minute {
                alerts[alerts.count - 1].fireDate = item.fire
                alerts[alerts.count - 1].words.append(item.word)
            } else {
                alerts.append(.init(fireDate: item.fire, words: [item.word], firstDue: item.fire))
            }
        }
        return Array(alerts.prefix(limit))
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
