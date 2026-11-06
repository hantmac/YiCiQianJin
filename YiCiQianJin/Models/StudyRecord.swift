import Foundation

struct StudyRecord: Codable, Identifiable, Equatable {
    var id: String { "\(date)_\(word)" }
    let date: String      // yyyy-MM-dd
    let word: String
    let meaning: String
    let bookId: String
    let passed: Bool

    /// Stable identity of a word inside a book, used for review scheduling.
    var wordKey: String { WordKey.make(bookId: bookId, word: word) }
}

enum QuizSource: String, Codable {
    case exam     // 每日考试（考昨天的词）
    case review   // 温故复习
}

struct QuizResult: Codable, Equatable {
    let word: String
    let correct: Bool
    let date: String
    /// Optional so results saved by older versions (which had no source) still decode; nil means exam.
    var source: QuizSource? = nil
    var bookId: String? = nil

    var effectiveSource: QuizSource { source ?? .exam }
}

enum WordKey {
    static func make(bookId: String, word: String) -> String { "\(bookId)|\(word)" }
}
