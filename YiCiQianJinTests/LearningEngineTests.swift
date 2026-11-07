import XCTest
@testable import YiCiQianJin

/// Deterministic RNG so question generation is reproducible.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private func makeRecord(_ word: String, _ date: String, book: String = "cet4", meaning: String? = nil) -> StudyRecord {
    StudyRecord(date: date, word: word, meaning: meaning ?? "\(word)-释义", bookId: book, passed: true)
}

final class DayKeyTests: XCTestCase {
    func testAddingAcrossMonthAndYear() {
        XCTAssertEqual(DayKey.adding(1, to: "2026-01-31"), "2026-02-01")
        XCTAssertEqual(DayKey.adding(-1, to: "2026-01-01"), "2025-12-31")
        XCTAssertEqual(DayKey.adding(30, to: "2026-02-10"), "2026-03-12")
    }

    func testDistance() {
        XCTAssertEqual(DayKey.distance(from: "2026-02-27", to: "2026-03-02"), 3)
        XCTAssertEqual(DayKey.distance(from: "2026-03-02", to: "2026-02-27"), -3)
        XCTAssertEqual(DayKey.distance(from: "2026-03-02", to: "2026-03-02"), 0)
    }
}

final class AppStateMigrationTests: XCTestCase {
    /// JSON exactly as written by v1.0 (no 1.1 keys). Must decode without losing progress.
    func testDecodesLegacyStateAndMigratesBookProgress() throws {
        let legacy = """
        {"selectedBookId":"cet4","isPremium":false,"currentWordIndex":12,
         "studyRecords":[{"date":"2026-03-01","word":"cancel","meaning":"取消","bookId":"cet4","passed":true}],
         "todayStudied":true,"todayQuizPassed":false,"todayDate":"2026-03-01",
         "quizResults":[{"word":"cancel","correct":true,"date":"2026-03-02"}]}
        """
        let state = try JSONDecoder().decode(AppState.self, from: Data(legacy.utf8))
        XCTAssertEqual(state.selectedBookId, "cet4")
        XCTAssertEqual(state.currentWordIndex, 12)
        XCTAssertEqual(state.studyRecords.count, 1)
        XCTAssertEqual(state.bookProgress["cet4"], 12)
        XCTAssertEqual(state.quizResults.first?.effectiveSource, .exam)
        XCTAssertTrue(state.autoPronounce)
        XCTAssertFalse(state.reminderEnabled)
        XCTAssertEqual(state.reminderHour, 20)
        XCTAssertFalse(state.achievementsInitialized)
    }

    func testDecodesEmptyObject() throws {
        let state = try JSONDecoder().decode(AppState.self, from: Data("{}".utf8))
        XCTAssertNil(state.selectedBookId)
        XCTAssertTrue(state.studyRecords.isEmpty)
    }

    func testRoundTripKeepsNewFields() throws {
        var state = AppState()
        state.selectedBookId = "ielts"
        state.bookProgress = ["ielts": 3, "cet4": 9]
        state.reviewStates = ["ielts|word": ReviewState(stage: 2, dueAt: Date(timeIntervalSinceReferenceDate: 800_000_000), lastReviewedAt: nil, lapses: 1)]
        state.gameRecords = [GameRecord(date: "2026-03-01", kind: .blitz, score: 120, correct: 9, total: 11)]
        state.reminderEnabled = true
        state.reminderHour = 7
        state.quizResults = [QuizResult(word: "word", correct: false, date: "2026-03-01", source: .review, bookId: "ielts")]
        let decoded = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.bookProgress, state.bookProgress)
        XCTAssertEqual(decoded.reviewStates, state.reviewStates)
        XCTAssertTrue(decoded.reminderEnabled)
        XCTAssertEqual(decoded.reminderHour, 7)
        XCTAssertEqual(decoded.quizResults, state.quizResults)
        XCTAssertEqual(decoded.gameRecords, state.gameRecords)
    }
}

final class SpacedRepetitionTests: XCTestCase {
    private let cal = Calendar.current
    private func at(_ day: String, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: DayKey.date(from: day)!)!
    }
    private func startOf(_ day: String) -> Date { cal.startOfDay(for: DayKey.date(from: day)!) }
    private func review(_ s: ReviewState, _ grade: ReviewGrade, _ date: Date) -> ReviewState {
        SpacedRepetition.next(after: s, grade: grade, at: date)
    }

    func testNewWordFollowsSameDayNodes() {
        let learned = at("2026-03-01", 20)
        var s = SpacedRepetition.initial(learnedAt: learned)
        XCTAssertEqual(s.stage, 0)
        XCTAssertEqual(s.dueAt, learned.addingTimeInterval(5 * 60))
        XCTAssertFalse(SpacedRepetition.isDue(s, at: learned.addingTimeInterval(60)))

        var t = s.dueAt
        s = review(s, .remembered, t)
        XCTAssertEqual(s.stage, 1)
        XCTAssertEqual(s.dueAt, t.addingTimeInterval(30 * 60))

        t = s.dueAt
        s = review(s, .remembered, t)
        XCTAssertEqual(s.stage, 2)
        XCTAssertEqual(s.dueAt, t.addingTimeInterval(12 * 3600))

        // Day-long gaps land at the start of the target day.
        t = s.dueAt
        s = review(s, .remembered, t)
        XCTAssertEqual(s.stage, 3)
        XCTAssertEqual(s.dueAt, cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: t)))
    }

    func testOverdueReviewEarnsCredit() {
        // Skipped the same-day reviews; answered right the next morning (13 h later).
        let s = SpacedRepetition.initial(learnedAt: at("2026-03-01", 20))
        let next = review(s, .remembered, at("2026-03-02", 9))
        XCTAssertEqual(next.stage, 3)
        XCTAssertEqual(next.dueAt, startOf("2026-03-03"))
    }

    func testDayNodes() {
        var s = ReviewState(stage: 3, dueAt: startOf("2026-03-02"), lastReviewedAt: startOf("2026-03-01"))
        s = review(s, .remembered, at("2026-03-02"))
        XCTAssertEqual(s.stage, 4)
        XCTAssertEqual(s.due, "2026-03-04")
        s = review(s, .remembered, at("2026-03-04"))
        XCTAssertEqual(s.stage, 5)
        XCTAssertEqual(s.due, "2026-03-08")
    }

    func testFuzzyRepeatsTheGap() {
        let s = ReviewState(stage: 5, dueAt: startOf("2026-03-08"), lastReviewedAt: startOf("2026-03-04"))
        let next = review(s, .fuzzy, at("2026-03-08"))
        XCTAssertEqual(next.stage, 5)
        XCTAssertEqual(next.due, "2026-03-12")
    }

    func testForgotDropsTwoStagesAndRelearnsWithinADay() {
        let s = ReviewState(stage: 7, dueAt: startOf("2026-03-10"), lastReviewedAt: startOf("2026-02-23"))
        let next = review(s, .forgot, at("2026-03-10"))
        XCTAssertEqual(next.stage, 5)
        XCTAssertEqual(next.lapses, 1)
        XCTAssertEqual(next.due, "2026-03-11")
        // Remembered the next day: back on track with the long gap, not 2 days.
        let after = review(next, .remembered, at("2026-03-11"))
        XCTAssertEqual(after.stage, 6)
        XCTAssertEqual(after.due, "2026-03-18")
    }

    func testForgotNewWordStaysAtFiveMinutes() {
        let t = at("2026-03-01", 20, 5)
        let s = review(SpacedRepetition.initial(learnedAt: at("2026-03-01", 20)), .forgot, t)
        XCTAssertEqual(s.stage, 0)
        XCTAssertEqual(s.dueAt, t.addingTimeInterval(300))
    }

    func testCorrectBeforeDueDoesNotFastTrack() {
        let s = ReviewState(stage: 4, dueAt: startOf("2026-03-04"), lastReviewedAt: startOf("2026-03-02"))
        XCTAssertEqual(review(s, .remembered, at("2026-03-03")), s)
        XCTAssertEqual(review(s, .fuzzy, at("2026-03-03")), s)
    }

    func testStageIsCapped() {
        let last = SpacedRepetition.maxStage
        let s = ReviewState(stage: last, dueAt: startOf("2026-03-01"), lastReviewedAt: startOf("2026-01-01"))
        XCTAssertEqual(review(s, .remembered, at("2026-03-01")).stage, last)
    }

    func testRetentionIsEightyPercentWhenDue() {
        let learned = at("2026-03-01", 20)
        let s = SpacedRepetition.initial(learnedAt: learned)
        XCTAssertEqual(SpacedRepetition.retention(s, at: learned), 1, accuracy: 0.0001)
        XCTAssertEqual(SpacedRepetition.retention(s, at: s.dueAt), 0.8, accuracy: 0.0001)
        XCTAssertLessThan(SpacedRepetition.retention(s, at: s.dueAt.addingTimeInterval(600)), 0.8)
        // Ebbinghaus: roughly a third left after one day without review.
        XCTAssertEqual(SpacedRepetition.ebbinghausRetention(minutes: 1440), 0.3, accuracy: 0.05)
    }

    func testLegacyStateMigratesToDayNodes() throws {
        let json = #"{"stage":1,"due":"2026-03-04"}"#
        let s = try JSONDecoder().decode(ReviewState.self, from: Data(json.utf8))
        XCTAssertEqual(s.stage, 4) // old 2-day gap = new 2-day node
        XCTAssertEqual(s.dueAt, startOf("2026-03-04"))
        XCTAssertEqual(s.lapses, 0)
        // Round trip keeps the new format.
        let again = try JSONDecoder().decode(ReviewState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(again, s)
    }

    func testLegacyDefaultIsDueNextDay() {
        let s = SpacedRepetition.legacyDefault(learnedOn: "2026-03-01")
        XCTAssertEqual(s.stage, SpacedRepetition.firstDayStage)
        XCTAssertEqual(s.due, "2026-03-02")
        XCTAssertFalse(SpacedRepetition.isDue(s, at: at("2026-03-01", 23)))
        XCTAssertTrue(SpacedRepetition.isDue(s, at: at("2026-03-02", 0, 1)))
    }

    func testUniqueWordsKeepsEarliest() {
        let list = [makeRecord("a", "2026-03-01"), makeRecord("b", "2026-03-01"), makeRecord("a", "2026-03-05")]
        XCTAssertEqual(list.uniqueWords().map(\.date), ["2026-03-01", "2026-03-01"])
    }
}

final class LearningStatsTests: XCTestCase {
    func testStreakCountsFromYesterdayWhenTodayNotDone() {
        let dates: Set<String> = ["2026-03-08", "2026-03-09", "2026-03-10"]
        XCTAssertEqual(LearningStats.currentStreak(dates: dates, today: "2026-03-11"), 3)
        XCTAssertEqual(LearningStats.currentStreak(dates: dates, today: "2026-03-10"), 3)
        XCTAssertEqual(LearningStats.currentStreak(dates: dates, today: "2026-03-12"), 0)
    }

    func testLongestStreak() {
        let dates: Set<String> = ["2026-02-27", "2026-02-28", "2026-03-01", "2026-03-05", "2026-03-06"]
        XCTAssertEqual(LearningStats.longestStreak(dates: dates), 3)
        XCTAssertEqual(LearningStats.longestStreak(dates: []), 0)
    }

    func testXPFormulaAndRetakeDedup() {
        var state = AppState()
        state.studyRecords = [makeRecord("a", "2026-03-01"), makeRecord("b", "2026-03-02")]
        state.quizResults = [
            QuizResult(word: "a", correct: true, date: "2026-03-02", source: .exam, bookId: "cet4"),
            // Retaking the same exam the same day must not pay out again.
            QuizResult(word: "a", correct: true, date: "2026-03-02", source: .exam, bookId: "cet4"),
            QuizResult(word: "a", correct: true, date: "2026-03-04", source: .review, bookId: "cet4"),
        ]
        let stats = LearningStats(state: state, today: "2026-03-04")
        // 2 words ×10 + 1 exam ×5 + 1 perfect exam day ×10 + 1 review ×3
        XCTAssertEqual(stats.xp, 20 + 5 + 10 + 3)
        XCTAssertEqual(stats.perfectExamDays, 1)
        XCTAssertEqual(stats.reviewCorrect, 1)
    }

    func testPerfectExamRequiresAllCorrect() {
        var state = AppState()
        state.quizResults = [
            QuizResult(word: "a", correct: true, date: "2026-03-02", source: .exam),
            QuizResult(word: "b", correct: false, date: "2026-03-02", source: .exam),
        ]
        XCTAssertEqual(LearningStats(state: state, today: "2026-03-02").perfectExamDays, 0)
    }

    func testCorrectedMistakes() {
        var state = AppState()
        state.quizResults = [
            QuizResult(word: "a", correct: true, date: "2026-03-01"),
            QuizResult(word: "b", correct: false, date: "2026-03-01"),
            QuizResult(word: "b", correct: true, date: "2026-03-02", source: .review),
        ]
        XCTAssertEqual(LearningStats(state: state, today: "2026-03-02").correctedMistakes, 1)
    }

    func testMasteredWords() {
        var state = AppState()
        state.studyRecords = [makeRecord("a", "2026-03-01"), makeRecord("b", "2026-03-01")]
        state.reviewStates = ["cet4|a": ReviewState(stage: SpacedRepetition.masteredStage, dueAt: Date())]
        XCTAssertEqual(LearningStats(state: state, today: "2026-03-02").masteredWords, 1)
    }
}

final class GameTests: XCTestCase {
    func testGameXPIsCappedPerDay() {
        var state = AppState()
        state.gameRecords = [
            GameRecord(date: "2026-03-01", kind: .blitz, score: 300, correct: 25, total: 28),
            GameRecord(date: "2026-03-01", kind: .match, score: 40, correct: 15, total: 15),
            GameRecord(date: "2026-03-02", kind: .match, score: 35, correct: 15, total: 15),
        ]
        let stats = LearningStats(state: state, today: "2026-03-02")
        XCTAssertEqual(stats.gameXP, LearningStats.Reward.gameDailyCap + 15)
        XCTAssertEqual(stats.bestBlitz, 300)
        XCTAssertEqual(stats.gamesPlayed, 3)
        XCTAssertEqual(GameRules.best(.match, in: state.gameRecords), 35)
    }

    func testBlitzPointsGrowWithCombo() {
        XCTAssertEqual(GameRules.blitzPoints(combo: 1), 10)
        XCTAssertEqual(GameRules.blitzPoints(combo: 3), 14)
        XCTAssertEqual(GameRules.blitzPoints(combo: 50), 20)
    }

    func testShortMeaning() {
        XCTAssertEqual(GameRules.shortMeaning("取消， 撤销； 删去"), "取消，撤销")
        XCTAssertEqual(GameRules.shortMeaning("水壶"), "水壶")
        XCTAssertEqual(GameRules.shortMeaning("伸展，延续，伸长，拉长，倾注全力"), "伸展")
    }
}

final class LevelAndAchievementTests: XCTestCase {
    func testLevelThresholds() {
        XCTAssertEqual(Level.for(xp: 0).title, "词汇萌新")
        XCTAssertEqual(Level.for(xp: 99).index, 0)
        XCTAssertEqual(Level.for(xp: 100).index, 1)
        XCTAssertEqual(Level.for(xp: 10_000).title, "千金状元")
        XCTAssertNil(Level.for(xp: 50_000).nextXP)
        XCTAssertEqual(Level.for(xp: 200).progress(xp: 200), 0.5, accuracy: 0.001)
    }

    func testAchievementsUnlockAndUniqueIds() {
        var stats = LearningStats()
        XCTAssertTrue(Achievement.unlocked(stats).isEmpty)
        stats.totalWords = 10
        stats.longestStreak = 3
        let ids = Set(Achievement.unlocked(stats).map(\.id))
        XCTAssertEqual(ids, ["first_word", "words_10", "streak_3"])
        XCTAssertEqual(Set(Achievement.all.map(\.id)).count, Achievement.all.count)
    }
}

final class QuestionFactoryTests: XCTestCase {
    private let pool = (0..<20).map { Word(word: "word\($0)", meaning: "释义\($0)", phonetic: "") }

    func testOptionQuestionsContainAnswerOnce() {
        var rng = SeededRNG(state: 1)
        let r = makeRecord("apple", "2026-03-01", meaning: "苹果")
        for kind in [QuestionKind.chooseMeaning, .chooseWord, .listen] {
            let q = QuestionFactory.make(for: r, pool: pool, kind: kind, using: &rng)
            XCTAssertEqual(q.kind, kind)
            XCTAssertEqual(q.options.count, 4)
            XCTAssertEqual(Set(q.options).count, 4)
            XCTAssertEqual(q.options.filter { $0 == q.answer }.count, 1)
        }
    }

    func testFillLettersBlanksOnlyLetters() {
        var rng = SeededRNG(state: 42)
        let r = makeRecord("Good morning!", "2026-03-01", book: "middle")
        for _ in 0..<20 {
            let q = QuestionFactory.make(for: r, pool: pool, kind: .fillLetters, using: &rng)
            let chars = Array(r.word)
            XCTAssertEqual(q.pattern.count, chars.count)
            var expected: [Character] = []
            for (i, slot) in q.pattern.enumerated() {
                if let slot { XCTAssertEqual(slot, chars[i]) } else {
                    XCTAssertTrue(chars[i].isASCIILetter)
                    expected.append(Character(chars[i].lowercased()))
                }
            }
            XCTAssertEqual(q.missing, expected)
            XCTAssertFalse(q.missing.isEmpty)
            XCTAssertEqual(q.tiles.count, q.missing.count + 2)
            // Every missing letter must be available among the tiles.
            var tileLetters = q.tiles.map(\.letter)
            for letter in q.missing {
                guard let idx = tileLetters.firstIndex(of: letter) else {
                    return XCTFail("missing letter \(letter) not offered as a tile")
                }
                tileLetters.remove(at: idx)
            }
        }
    }

    func testFallsBackWhenPoolTooSmall() {
        var rng = SeededRNG(state: 7)
        let q = QuestionFactory.make(for: makeRecord("ox", "2026-03-01"), pool: [], kind: .chooseWord, using: &rng)
        XCTAssertEqual(q.kind, .spell)
    }

    func testAnswerMatcher() {
        XCTAssertTrue(AnswerMatcher.matches("good morning", "Good morning!"))
        XCTAssertTrue(AnswerMatcher.matches(" Apple ", "apple"))
        XCTAssertTrue(AnswerMatcher.matches("uptodate", "up-to-date"))
        XCTAssertFalse(AnswerMatcher.matches("appl", "apple"))
        XCTAssertFalse(AnswerMatcher.matches("!!", "apple"))
    }
}

final class WordAtlasTests: XCTestCase {
    func testEveryIllustrationReferencedByAtlasIsBundled() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "atlas", withExtension: "json"))
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: Any]])
        XCTAssertGreaterThan(raw.count, 5000)
        let ids = raw.values.compactMap { $0["i"] as? String }
        XCTAssertEqual(ids.count, raw.count, "imported words should all have an illustration")
        let missing = ids.filter { WordAtlas.imageURL(id: $0) == nil }
        XCTAssertTrue(missing.isEmpty, "missing illustrations: \(missing.prefix(5))")
    }

    func testLookupIsCaseInsensitiveAndHasExamples() throws {
        let entry = try XCTUnwrap(WordAtlas.entry(for: " Library "))
        XCTAssertEqual(entry.imageID, "library")
        XCTAssertEqual(entry.examples.count, 2)
        XCTAssertFalse(entry.examples[0].zh.isEmpty)
        XCTAssertNil(WordAtlas.entry(for: "zzqxnotaword"))
    }

    func testImageDecodesAndThumbnailIsDownsampled() async throws {
        let loadedFull = await WordAtlas.image(for: "library")
        let full = try XCTUnwrap(loadedFull)
        XCTAssertEqual(full.size.width * full.scale, 512, accuracy: 1)
        let loadedThumb = await WordAtlas.image(for: "library", maxPixel: 128)
        let thumb = try XCTUnwrap(loadedThumb)
        XCTAssertLessThanOrEqual(thumb.size.width * thumb.scale, 128.5)
    }

    func testEveryBookWordWithAtlasEntryResolves() {
        // Guards the importer's key normalization against the in-app lookup.
        let words = WordData.books.flatMap(\.words)
        let resolved = words.filter { WordAtlas.entry(for: $0.word) != nil }
        XCTAssertGreaterThan(Double(resolved.count) / Double(words.count), 0.5)
    }
}

final class PictureQuestionTests: XCTestCase {
    private let pool = (0..<20).map { Word(word: "word\($0)", meaning: "释义\($0)", phonetic: "") }

    func testPictureOnlyOfferedWhenWordHasImage() {
        var rng = SeededRNG(state: 3)
        let r = StudyRecord(date: "2026-03-01", word: "library", meaning: "图书馆", bookId: "cet4", passed: true)
        let without = QuestionFactory.make(for: r, pool: pool, kind: .picture, hasImage: false, using: &rng)
        XCTAssertNotEqual(without.kind, .picture)
        let with = QuestionFactory.make(for: r, pool: pool, kind: .picture, hasImage: true, using: &rng)
        XCTAssertEqual(with.kind, .picture)
        XCTAssertEqual(with.options.count, 4)
        XCTAssertTrue(with.options.contains("library"))
    }
}

final class AdaptiveMetricsTests: XCTestCase {
    func testSplitDecision() {
        // iPhone Duo outer display, portrait / landscape (points).
        XCTAssertFalse(AdaptiveMetrics.useSplit(size: CGSize(width: 466, height: 678), hasActiveDivision: false))
        XCTAssertTrue(AdaptiveMetrics.useSplit(size: CGSize(width: 678, height: 466), hasActiveDivision: false))
        // Inner display fully open in portrait stays single column; folded it splits along the hinge.
        XCTAssertFalse(AdaptiveMetrics.useSplit(size: CGSize(width: 669, height: 951), hasActiveDivision: false))
        XCTAssertTrue(AdaptiveMetrics.useSplit(size: CGSize(width: 669, height: 951), hasActiveDivision: true))
        XCTAssertTrue(AdaptiveMetrics.useSplit(size: CGSize(width: 951, height: 669), hasActiveDivision: false))
        // Regular iPhone portrait / small landscape.
        XCTAssertFalse(AdaptiveMetrics.useSplit(size: CGSize(width: 402, height: 874), hasActiveDivision: false))
        XCTAssertFalse(AdaptiveMetrics.useSplit(size: CGSize(width: 560, height: 320), hasActiveDivision: false))
    }
}
