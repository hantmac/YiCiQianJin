import Foundation

enum QuestionKind: String, CaseIterable {
    case chooseMeaning  // 看单词选释义
    case chooseWord     // 看释义选单词
    case listen         // 听发音选单词
    case fillLetters    // 点选字母补全单词
    case spell          // 根据释义拼写
    case picture        // 看插画选单词

    var prompt: String {
        switch self {
        case .chooseMeaning: return "选出正确的中文意思"
        case .chooseWord: return "哪个单词是这个意思？"
        case .listen: return "听发音，选出你听到的单词"
        case .fillLetters: return "点选字母，补全单词"
        case .spell: return "根据意思拼写单词"
        case .picture: return "看图，选出画的是哪个单词"
        }
    }

    var usesOptions: Bool { [.chooseMeaning, .chooseWord, .listen, .picture].contains(self) }
}

struct LetterTile: Identifiable, Equatable {
    let id: Int
    let letter: Character
}

struct QuizQuestion: Identifiable, Equatable {
    let id = UUID()
    let record: StudyRecord
    let kind: QuestionKind
    /// Choice texts for option-based kinds.
    let options: [String]
    let answer: String
    /// For `.fillLetters`: the word with nil at each blank position.
    let pattern: [Character?]
    /// For `.fillLetters`: the expected letters, in blank order.
    let missing: [Character]
    let tiles: [LetterTile]

    static func == (lhs: QuizQuestion, rhs: QuizQuestion) -> Bool { lhs.id == rhs.id }
}

enum QuestionFactory {
    /// Builds a question for `record`; `pool` supplies distractors (usually the record's word book).
    static func make<G: RandomNumberGenerator>(
        for record: StudyRecord,
        pool: [Word],
        kind preferred: QuestionKind? = nil,
        hasImage: Bool = false,
        using rng: inout G
    ) -> QuizQuestion {
        let meanings = distinct(pool.map(\.meaning).filter { $0 != record.meaning })
        let words = distinct(pool.map(\.word).filter { $0.lowercased() != record.word.lowercased() })
        let letterCount = record.word.filter(\.isASCIILetter).count

        var allowed: [QuestionKind] = [.spell]
        if meanings.count >= 3 { allowed.append(.chooseMeaning) }
        if words.count >= 3 { allowed += [.chooseWord, .listen] }
        if letterCount >= 3 { allowed.append(.fillLetters) }
        if hasImage && words.count >= 3 { allowed.append(.picture) }

        let kind = preferred.flatMap { allowed.contains($0) ? $0 : nil } ?? allowed.randomElement(using: &rng)!

        switch kind {
        case .chooseMeaning:
            let options = ([record.meaning] + meanings.shuffled(using: &rng).prefix(3)).shuffled(using: &rng)
            return QuizQuestion(record: record, kind: kind, options: options, answer: record.meaning,
                                pattern: [], missing: [], tiles: [])
        case .chooseWord, .listen, .picture:
            let options = ([record.word] + words.shuffled(using: &rng).prefix(3)).shuffled(using: &rng)
            return QuizQuestion(record: record, kind: kind, options: options, answer: record.word,
                                pattern: [], missing: [], tiles: [])
        case .fillLetters:
            return fillLetters(record: record, using: &rng)
        case .spell:
            return QuizQuestion(record: record, kind: .spell, options: [], answer: record.word,
                                pattern: [], missing: [], tiles: [])
        }
    }

    static func make(for record: StudyRecord, pool: [Word], kind: QuestionKind? = nil) -> QuizQuestion {
        var rng = SystemRandomNumberGenerator()
        return make(for: record, pool: pool, kind: kind, hasImage: WordAtlas.hasImage(record.word), using: &rng)
    }

    private static func fillLetters<G: RandomNumberGenerator>(record: StudyRecord, using rng: inout G) -> QuizQuestion {
        let chars = Array(record.word)
        let letterIndices = chars.indices.filter { chars[$0].isASCIILetter }
        let blankCount = min(5, max(1, Int(Double(letterIndices.count) * 0.4)))
        let blanks = Set(letterIndices.shuffled(using: &rng).prefix(blankCount))

        let pattern: [Character?] = chars.indices.map { blanks.contains($0) ? nil : chars[$0] }
        let missing = chars.indices.filter { blanks.contains($0) }.map { Character(chars[$0].lowercased()) }

        // Two decoy letters make the tiles a real choice instead of a pure ordering puzzle.
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        let decoys = (0..<2).map { _ in alphabet.randomElement(using: &rng)! }
        let tiles = (missing + decoys).shuffled(using: &rng).enumerated().map { LetterTile(id: $0.offset, letter: $0.element) }

        return QuizQuestion(record: record, kind: .fillLetters, options: [], answer: record.word,
                            pattern: pattern, missing: missing, tiles: tiles)
    }

    private static func distinct(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

enum AnswerMatcher {
    /// Case-, space- and punctuation-insensitive comparison so "Good morning!" accepts "good morning".
    static func matches(_ input: String, _ answer: String) -> Bool {
        let a = normalize(input)
        return !a.isEmpty && a == normalize(answer)
    }

    static func normalize(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}

extension Character {
    var isASCIILetter: Bool { isASCII && isLetter }
}
