import Foundation

struct StudyRecord: Codable, Identifiable, Equatable {
    var id: String { "\(date)_\(word)" }
    let date: String      // yyyy-MM-dd
    let word: String
    let meaning: String
    let bookId: String
    let passed: Bool
}

struct QuizResult: Codable {
    let word: String
    let correct: Bool
    let date: String
}
