import Foundation

/// Everything derived from the persisted state that drives motivation features.
/// Derived (never stored) so it can't drift out of sync with the actual learning history.
struct LearningStats: Equatable {
    var totalWords = 0
    var currentStreak = 0
    var longestStreak = 0
    var studyDays = 0
    var xp = 0
    var perfectExamDays = 0
    var reviewCorrect = 0
    var masteredWords = 0
    var correctedMistakes = 0

    enum Reward {
        static let newWord = 10
        static let examCorrect = 5
        static let reviewCorrect = 3
        static let perfectExam = 10
    }

    init() {}

    init(state: AppState, today: String = DayKey.today()) {
        let unique = state.studyRecords.uniqueWords()
        totalWords = unique.count

        let dates = Set(state.studyRecords.map(\.date))
        studyDays = dates.count
        currentStreak = Self.currentStreak(dates: dates, today: today)
        longestStreak = max(Self.longestStreak(dates: dates), currentStreak)

        let exam = state.quizResults.filter { $0.effectiveSource == .exam }
        let review = state.quizResults.filter { $0.effectiveSource == .review }
        // Count each word at most once per day and source, so retaking a session can't farm XP.
        func uniqueCorrect(_ results: [QuizResult]) -> Int {
            Set(results.filter(\.correct).map { "\($0.date)|\($0.bookId ?? "")|\($0.word)" }).count
        }
        reviewCorrect = uniqueCorrect(review)
        perfectExamDays = Dictionary(grouping: exam, by: \.date).values
            .filter { !$0.isEmpty && $0.allSatisfy(\.correct) }
            .count

        xp = totalWords * Reward.newWord
            + uniqueCorrect(exam) * Reward.examCorrect
            + reviewCorrect * Reward.reviewCorrect
            + perfectExamDays * Reward.perfectExam

        masteredWords = unique.filter {
            SpacedRepetition.state(for: $0, in: state.reviewStates).stage >= SpacedRepetition.masteredStage
        }.count

        // A "corrected mistake" is a word answered wrong once and right on a later attempt.
        var wrongOnce = Set<String>()
        var corrected = Set<String>()
        for result in state.quizResults {
            if !result.correct {
                wrongOnce.insert(result.word)
            } else if wrongOnce.contains(result.word) {
                corrected.insert(result.word)
            }
        }
        correctedMistakes = corrected.count
    }

    static func currentStreak(dates: Set<String>, today: String) -> Int {
        // A streak survives until the end of today, so start from yesterday if today isn't done yet.
        var day = dates.contains(today) ? today : DayKey.adding(-1, to: today)
        var streak = 0
        while dates.contains(day) {
            streak += 1
            day = DayKey.adding(-1, to: day)
        }
        return streak
    }

    static func longestStreak(dates: Set<String>) -> Int {
        let sorted = dates.sorted()
        var best = 0
        var run = 0
        var previous: String?
        for day in sorted {
            if let previous, DayKey.distance(from: previous, to: day) == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}

// MARK: - Levels

struct Level: Equatable {
    let index: Int
    let title: String
    let minXP: Int
    /// XP needed for the next level, nil at the top level.
    let nextXP: Int?

    static let ladder: [(title: String, xp: Int)] = [
        ("词汇萌新", 0),
        ("识字书童", 100),
        ("勤学秀才", 300),
        ("博闻举人", 700),
        ("才高进士", 1500),
        ("学富探花", 3000),
        ("词林榜眼", 6000),
        ("千金状元", 10000),
    ]

    static func `for`(xp: Int) -> Level {
        let index = ladder.lastIndex { xp >= $0.xp } ?? 0
        let next = index + 1 < ladder.count ? ladder[index + 1].xp : nil
        return Level(index: index, title: ladder[index].title, minXP: ladder[index].xp, nextXP: next)
    }

    var nextTitle: String? {
        index + 1 < Self.ladder.count ? Self.ladder[index + 1].title : nil
    }

    /// 0...1 progress inside the current level.
    func progress(xp: Int) -> Double {
        guard let nextXP else { return 1 }
        return Double(xp - minXP) / Double(max(nextXP - minXP, 1))
    }
}

// MARK: - Achievements

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let target: Int
    let metric: (LearningStats) -> Int

    static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }

    func value(_ stats: LearningStats) -> Int { min(metric(stats), target) }
    func isUnlocked(_ stats: LearningStats) -> Bool { metric(stats) >= target }

    static let all: [Achievement] = [
        Achievement(id: "first_word", title: "初出茅庐", detail: "学会第 1 个单词", symbol: "leaf.fill", target: 1) { $0.totalWords },
        Achievement(id: "streak_3", title: "三日不辍", detail: "连续学习 3 天", symbol: "flame.fill", target: 3) { $0.longestStreak },
        Achievement(id: "words_10", title: "小有积累", detail: "累计学会 10 个单词", symbol: "books.vertical.fill", target: 10) { $0.totalWords },
        Achievement(id: "perfect_exam", title: "金榜题名", detail: "昨日考试全部答对", symbol: "rosette", target: 1) { $0.perfectExamDays },
        Achievement(id: "streak_7", title: "七日之功", detail: "连续学习 7 天", symbol: "flame.circle.fill", target: 7) { $0.longestStreak },
        Achievement(id: "comeback", title: "知错能改", detail: "把答错过的单词重新答对", symbol: "arrow.uturn.up.circle.fill", target: 1) { $0.correctedMistakes },
        Achievement(id: "review_20", title: "温故知新", detail: "复习时答对 20 次", symbol: "arrow.triangle.2.circlepath", target: 20) { $0.reviewCorrect },
        Achievement(id: "words_50", title: "半百词囊", detail: "累计学会 50 个单词", symbol: "bag.fill", target: 50) { $0.totalWords },
        Achievement(id: "mastered_10", title: "融会贯通", detail: "10 个单词达到「已掌握」", symbol: "brain.head.profile", target: 10) { $0.masteredWords },
        Achievement(id: "streak_30", title: "月度坚持", detail: "连续学习 30 天", symbol: "calendar.badge.checkmark", target: 30) { $0.longestStreak },
        Achievement(id: "words_100", title: "百词斩获", detail: "累计学会 100 个单词", symbol: "crown.fill", target: 100) { $0.totalWords },
        Achievement(id: "streak_100", title: "百日筑基", detail: "连续学习 100 天", symbol: "mountain.2.fill", target: 100) { $0.longestStreak },
        Achievement(id: "words_365", title: "一年之功", detail: "累计学会 365 个单词", symbol: "sun.max.fill", target: 365) { $0.totalWords },
    ]

    static func unlocked(_ stats: LearningStats) -> [Achievement] {
        all.filter { $0.isUnlocked(stats) }
    }
}
