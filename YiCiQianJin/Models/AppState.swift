import Foundation

struct ReviewState: Codable, Equatable {
    /// Memory stage; higher means a longer interval before the next review.
    var stage: Int
    /// Day key on which the word becomes due.
    var due: String
}

struct AppState: Codable {
    var selectedBookId: String?
    var isPremium: Bool = false
    var currentWordIndex: Int = 0
    var studyRecords: [StudyRecord] = []
    var todayStudied: Bool = false
    /// True once today's exam is finished (passed, or failed words reviewed).
    var todayQuizPassed: Bool = false
    var todayDate: String = ""
    var quizResults: [QuizResult] = []

    // Added in 1.1 — every new field must be decoded with a default below.
    var bookProgress: [String: Int] = [:]
    var reviewStates: [String: ReviewState] = [:]
    var seenAchievements: [String] = []
    var achievementsInitialized: Bool = false
    var reminderEnabled: Bool = false
    var reminderHour: Int = 20
    var reminderMinute: Int = 0
    var autoPronounce: Bool = true

    init() {}

    private enum CodingKeys: String, CodingKey {
        case selectedBookId, isPremium, currentWordIndex, studyRecords, todayStudied
        case todayQuizPassed, todayDate, quizResults
        case bookProgress, reviewStates, seenAchievements, achievementsInitialized
        case reminderEnabled, reminderHour, reminderMinute, autoPronounce
    }

    /// Tolerant decoding: data written by older versions lacks the newer keys,
    /// and the synthesized decoder would reject it and wipe the user's progress.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        selectedBookId = try c.decodeIfPresent(String.self, forKey: .selectedBookId)
        isPremium = try c.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        currentWordIndex = try c.decodeIfPresent(Int.self, forKey: .currentWordIndex) ?? 0
        studyRecords = try c.decodeIfPresent([StudyRecord].self, forKey: .studyRecords) ?? []
        todayStudied = try c.decodeIfPresent(Bool.self, forKey: .todayStudied) ?? false
        todayQuizPassed = try c.decodeIfPresent(Bool.self, forKey: .todayQuizPassed) ?? false
        todayDate = try c.decodeIfPresent(String.self, forKey: .todayDate) ?? ""
        quizResults = try c.decodeIfPresent([QuizResult].self, forKey: .quizResults) ?? []
        bookProgress = try c.decodeIfPresent([String: Int].self, forKey: .bookProgress) ?? [:]
        reviewStates = try c.decodeIfPresent([String: ReviewState].self, forKey: .reviewStates) ?? [:]
        seenAchievements = try c.decodeIfPresent([String].self, forKey: .seenAchievements) ?? []
        achievementsInitialized = try c.decodeIfPresent(Bool.self, forKey: .achievementsInitialized) ?? false
        reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 20
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        autoPronounce = try c.decodeIfPresent(Bool.self, forKey: .autoPronounce) ?? true

        // Older versions only tracked the index of the selected book.
        if let book = selectedBookId, bookProgress[book] == nil {
            bookProgress[book] = currentWordIndex
        }
    }
}
