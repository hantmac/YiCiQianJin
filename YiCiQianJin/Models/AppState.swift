import Foundation

struct AppState: Codable {
    var selectedBookId: String?
    var isPremium: Bool = false
    var currentWordIndex: Int = 0
    var studyRecords: [StudyRecord] = []
    var todayStudied: Bool = false
    var todayQuizPassed: Bool = false
    var todayDate: String = ""
    var quizResults: [QuizResult] = []
}
