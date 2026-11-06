import Foundation

/// Lightweight Leitner-style scheduler: each correct answer pushes the next review further out,
/// a wrong answer sends the word back to the start.
enum SpacedRepetition {
    /// Days until the next review for each stage (index = stage after answering).
    static let intervals = [1, 2, 4, 7, 15, 30, 60]
    /// Stage at which a word counts as "mastered".
    static let masteredStage = 4

    /// Schedule for a word that was just learned on `day`.
    static func initial(learnedOn day: String) -> ReviewState {
        ReviewState(stage: 0, due: DayKey.adding(intervals[0], to: day))
    }

    static func next(after state: ReviewState, correct: Bool, on day: String) -> ReviewState {
        if correct {
            // Answering a word that isn't due yet (e.g. retaking a session) must not fast-track it.
            guard isDue(state, today: day) else { return state }
            let stage = min(state.stage + 1, intervals.count - 1)
            return ReviewState(stage: stage, due: DayKey.adding(intervals[stage], to: day))
        }
        return ReviewState(stage: 0, due: DayKey.adding(intervals[0], to: day))
    }

    /// Schedule for a record, falling back to the default for words learned before scheduling existed.
    static func state(for record: StudyRecord, in states: [String: ReviewState]) -> ReviewState {
        states[record.wordKey] ?? initial(learnedOn: record.date)
    }

    static func isDue(_ state: ReviewState, today: String) -> Bool {
        DayKey.distance(from: state.due, to: today) >= 0
    }

    static func mastery(of stage: Int) -> Mastery {
        switch stage {
        case ..<1: return .new
        case ..<masteredStage: return .learning
        default: return .mastered
        }
    }

    enum Mastery: String {
        case new = "新学"
        case learning = "熟悉中"
        case mastered = "已掌握"
    }
}

extension Array where Element == StudyRecord {
    /// One record per word (the earliest learning date wins), preserving first-seen order.
    func uniqueWords() -> [StudyRecord] {
        var seen = Set<String>()
        return filter { seen.insert($0.wordKey).inserted }
    }
}
