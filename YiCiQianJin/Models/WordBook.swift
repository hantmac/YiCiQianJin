import Foundation

struct WordBook: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let words: [Word]
}
