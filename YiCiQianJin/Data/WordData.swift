import Foundation

struct WordData {
    struct BookMeta {
        let id: String
        let name: String
        let icon: String
        let fileName: String
    }

    private static let bookMetas: [BookMeta] = [
        BookMeta(id: "primary", name: "小学词汇", icon: "🌱", fileName: "primary"),
        BookMeta(id: "middle", name: "中学词汇", icon: "📗", fileName: "middle"),
        BookMeta(id: "gaokao", name: "高考词汇", icon: "🎓", fileName: "gaokao"),
        BookMeta(id: "cet4", name: "四级词汇", icon: "📘", fileName: "cet4"),
        BookMeta(id: "cet6", name: "六级词汇", icon: "📙", fileName: "cet6"),
        BookMeta(id: "ielts", name: "雅思词汇", icon: "🌍", fileName: "ielts"),
        BookMeta(id: "toefl", name: "托福词汇", icon: "🇺🇸", fileName: "toefl"),
    ]

    static let books: [WordBook] = bookMetas.map { meta in
        let words = loadWords(from: meta.fileName)
        return WordBook(
            id: meta.id,
            name: meta.name,
            icon: meta.icon,
            description: "\(meta.name)，共\(words.count)词",
            words: words
        )
    }

    private static func loadWords(from fileName: String) -> [Word] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([Word].self, from: data) else {
            return []
        }
        return words
    }
}
