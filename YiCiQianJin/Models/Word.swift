import Foundation

struct Word: Codable, Identifiable, Equatable {
    var id: String { word }
    let word: String
    let meaning: String
    let phonetic: String
}
