import Foundation

enum GameKind: String, Codable, CaseIterable, Identifiable {
    case blitz  // 60 秒闪电战
    case match  // 词义配对

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blitz: return "60 秒闪电战"
        case .match: return "词义配对"
        }
    }

    var symbol: String {
        switch self {
        case .blitz: return "bolt.fill"
        case .match: return "square.grid.2x2.fill"
        }
    }

    /// Learned words needed before the game can be played.
    var minimumWords: Int {
        switch self {
        case .blitz: return 4
        case .match: return 5
        }
    }
}

/// One finished game. Games only use words already learned and never change review schedules.
struct GameRecord: Codable, Equatable {
    let date: String
    let kind: GameKind
    /// Blitz: points. Match: elapsed seconds (lower is better).
    let score: Int
    let correct: Int
    let total: Int
}

enum GameRules {
    static let blitzSeconds = 60
    /// Seconds lost for a wrong blitz answer.
    static let blitzPenalty = 3
    /// Every this many answers in a row adds `blitzBonusSeconds`.
    static let blitzBonusEvery = 5
    static let blitzBonusSeconds = 2
    /// Every this many answers in a row starts a 金色时刻 (double points).
    static let feverEvery = 10
    static let feverSeconds = 5.0
    /// Questions before pictures and listening join the mix.
    static let blitzWarmup = 3
    static let matchPairsPerRound = 5
    static let matchRounds = 3

    /// Blitz points for a correct answer at the given combo (1-based).
    static func blitzPoints(combo: Int) -> Int {
        10 + 2 * min(max(combo - 1, 0), 5)
    }

    enum Rank: String, CaseIterable {
        case s = "S", a = "A", b = "B", c = "C"

        var title: String {
            switch self {
            case .s: return "词汇大师"
            case .a: return "反应神速"
            case .b: return "稳步提升"
            case .c: return "再接再厉"
            }
        }
    }

    static func blitzRank(score: Int) -> Rank {
        switch score {
        case 320...: return .s
        case 220...: return .a
        case 130...: return .b
        default: return .c
        }
    }

    /// 1–3 stars for a match round of `pairs` pairs.
    static func matchStars(seconds: Double, mistakes: Int, pairs: Int = matchPairsPerRound) -> Int {
        let perPair = seconds / Double(max(pairs, 1))
        if mistakes == 0 && perPair <= 2.6 { return 3 }
        if mistakes <= 1 && perPair <= 4.5 { return 2 }
        return 1
    }

    static func best(_ kind: GameKind, in records: [GameRecord]) -> Int? {
        let own = records.filter { $0.kind == kind }
        switch kind {
        case .blitz: return own.map(\.score).max()
        // Only fully cleared boards count for the best time.
        case .match: return own.filter { $0.correct == $0.total }.map(\.score).min()
        }
    }

    /// First sense of a meaning, short enough for a game tile ("取消， 撤销； 删去" → "取消，撤销").
    static func shortMeaning(_ meaning: String) -> String {
        func firstPart(_ text: String, _ separators: Set<Character>) -> String {
            let part = text.split(whereSeparator: { separators.contains($0) }).first.map(String.init) ?? text
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? text : trimmed
        }
        // Source data pads Chinese punctuation with a space ("取消， 撤销").
        let tidy = meaning.replacingOccurrences(of: "， ", with: "，").replacingOccurrences(of: "； ", with: "；")
        let sense = firstPart(tidy, ["；", ";"])
        return sense.count > 10 ? firstPart(sense, ["，", ",", "、"]) : sense
    }
}
