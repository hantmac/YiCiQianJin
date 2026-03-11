import Foundation
import SwiftUI

enum QuizType: CaseIterable {
    case fillBlank      // 填写缺失字母
    case chooseMeaning  // 选择中文意思
    case writeWord      // 根据中文写单词
}

@Observable
class StudyViewModel {
    private let storageKey = "yiciqianjin_state"

    var state: AppState {
        didSet { save() }
    }

    // Navigation
    var currentPage: AppPage = .home
    var showCheckIn = false
    var failedRecord: StudyRecord?

    // StoreKit
    let storeManager = StoreManager()

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            self.state = saved
        } else {
            self.state = AppState()
        }
        resetIfNewDay()
        if state.selectedBookId == nil {
            currentPage = .bookSelect
        }
        // Sync purchase state on launch
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

    private func resetIfNewDay() {
        let today = Self.todayString()
        if state.todayDate != today {
            state.todayStudied = false
            state.todayQuizPassed = false
            state.todayDate = today
        }
    }

    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func yesterdayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
    }

    // MARK: - Computed

    var currentBook: WordBook? {
        WordData.books.first { $0.id == state.selectedBookId }
    }

    var currentWord: Word? {
        guard let book = currentBook,
              state.currentWordIndex < book.words.count else { return nil }
        return book.words[state.currentWordIndex]
    }

    var yesterdayWords: [StudyRecord] {
        let yesterday = Self.yesterdayString()
        return state.studyRecords.filter { $0.date == yesterday }
    }

    var todayRecords: [StudyRecord] {
        let today = Self.todayString()
        return state.studyRecords.filter { $0.date == today }
    }

    var hasStudiedToday: Bool {
        state.todayDate == Self.todayString() && state.todayStudied
    }

    var isBookComplete: Bool {
        guard let book = currentBook else { return false }
        return state.currentWordIndex >= book.words.count
    }

    var streakDays: Int {
        let dates = Set(state.studyRecords.map { $0.date }).sorted().reversed()
        var streak = 0
        let cal = Calendar.current
        let today = Date()
        for (i, dateStr) in dates.enumerated() {
            guard let expected = cal.date(byAdding: .day, value: -i, to: today) else { break }
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            if dateStr == f.string(from: expected) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    var totalWords: Int {
        Set(state.studyRecords.map { $0.word }).count
    }

    var studyDates: [String: [StudyRecord]] {
        Dictionary(grouping: state.studyRecords, by: { $0.date })
    }

    // MARK: - Actions

    func selectBook(_ bookId: String) {
        state.selectedBookId = bookId
        state.currentWordIndex = 0
        currentPage = .home
    }

    func startStudy() {
        if isBookComplete {
            currentPage = .bookComplete
            return
        }
        if !yesterdayWords.isEmpty && !state.todayQuizPassed {
            currentPage = .quiz
        } else {
            currentPage = .study
        }
    }

    func markWordStudied() {
        guard let word = currentWord, let bookId = state.selectedBookId else { return }
        let record = StudyRecord(
            date: Self.todayString(),
            word: word.word,
            meaning: word.meaning,
            bookId: bookId,
            passed: true
        )
        state.studyRecords.append(record)
        state.todayStudied = true
        state.todayDate = Self.todayString()
        state.currentWordIndex += 1
        showCheckIn = true
    }

    func quizPassed() {
        state.todayQuizPassed = true
        state.todayDate = Self.todayString()
        currentPage = .study
    }

    func quizFailed(_ record: StudyRecord) {
        failedRecord = record
        currentPage = .reviewFailed
    }

    func reviewDone() {
        failedRecord = nil
        currentPage = .study
    }

    func recordQuizResult(word: String, correct: Bool) {
        let result = QuizResult(word: word, correct: correct, date: Self.todayString())
        state.quizResults.append(result)
    }

    func upgradeToPremium() async -> Bool {
        let success = await storeManager.purchase()
        if success {
            state.isPremium = true
            currentPage = .home
        }
        return success
    }

    func closeCheckIn() {
        showCheckIn = false
        currentPage = .home
    }
}

enum AppPage {
    case home, bookSelect, study, quiz, calendar, premium, reviewFailed, bookComplete
}
