import Foundation

/// How well a word was recalled in a review.
enum ReviewGrade: String, Codable, CaseIterable {
    case remembered  // 记得
    case fuzzy       // 模糊
    case forgot      // 忘了
}

/// Memory schedule of one word.
struct ReviewState: Codable, Equatable {
    /// Number of reviews survived in the chain; `SpacedRepetition.nodes[stage]` is the next gap.
    var stage: Int
    /// Moment the word becomes due. Day-long gaps are aligned to the start of the day.
    var dueAt: Date
    /// Last time the word was learned or reviewed.
    var lastReviewedAt: Date?
    /// How many times the word was forgotten.
    var lapses: Int

    init(stage: Int, dueAt: Date, lastReviewedAt: Date? = nil, lapses: Int = 0) {
        self.stage = stage
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
        self.lapses = lapses
    }

    /// Day key of the due date.
    var due: String { DayKey.string(from: dueAt) }

    /// Start of the current gap; estimated for states written before it was stored.
    var anchor: Date {
        lastReviewedAt ?? dueAt.addingTimeInterval(-SpacedRepetition.nodes[SpacedRepetition.clamp(stage)].interval)
    }

    private enum CodingKeys: String, CodingKey { case stage, due, dueAt, last, lapses }

    /// States written by 1.x only have a day-based `stage` and a `due` day key. Their stages map
    /// onto the day-long Ebbinghaus nodes (old stage 0 = 1 day = new stage 3).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawStage = try c.decodeIfPresent(Int.self, forKey: .stage) ?? 0
        lapses = try c.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
        lastReviewedAt = try c.decodeIfPresent(Date.self, forKey: .last)
        if let dueAt = try c.decodeIfPresent(Date.self, forKey: .dueAt) {
            self.stage = SpacedRepetition.clamp(rawStage)
            self.dueAt = dueAt
        } else {
            let dueKey = try c.decodeIfPresent(String.self, forKey: .due) ?? DayKey.today()
            self.stage = SpacedRepetition.clamp(rawStage + SpacedRepetition.legacyStageOffset)
            self.dueAt = Calendar.current.startOfDay(for: DayKey.date(from: dueKey) ?? Date())
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(stage, forKey: .stage)
        try c.encode(dueAt, forKey: .dueAt)
        try c.encode(due, forKey: .due)
        try c.encodeIfPresent(lastReviewedAt, forKey: .last)
        try c.encode(lapses, forKey: .lapses)
    }
}

/// Ebbinghaus-style scheduler. A new word is reviewed after 5 minutes, 30 minutes and 12 hours,
/// then after 1, 2, 4, 7, 15, 30 and 60 days. Reviews are planned for the moment estimated
/// retention falls to `dueRetention`.
enum SpacedRepetition {
    struct Node: Equatable {
        let interval: TimeInterval
        /// Short label for charts ("5分", "1天").
        let short: String
        /// Full label ("5 分钟", "1 天").
        let label: String
        var days: Int? { interval >= day ? Int(interval / day) : nil }
    }

    static let minute: TimeInterval = 60
    static let hour: TimeInterval = 3600
    static let day: TimeInterval = 86_400

    static let nodes: [Node] = [
        Node(interval: 5 * minute, short: "5分", label: "5 分钟"),
        Node(interval: 30 * minute, short: "30分", label: "30 分钟"),
        Node(interval: 12 * hour, short: "12时", label: "12 小时"),
        Node(interval: 1 * day, short: "1天", label: "1 天"),
        Node(interval: 2 * day, short: "2天", label: "2 天"),
        Node(interval: 4 * day, short: "4天", label: "4 天"),
        Node(interval: 7 * day, short: "7天", label: "7 天"),
        Node(interval: 15 * day, short: "15天", label: "15 天"),
        Node(interval: 30 * day, short: "30天", label: "30 天"),
        Node(interval: 60 * day, short: "60天", label: "60 天"),
    ]

    static var maxStage: Int { nodes.count - 1 }
    /// First day-long node; same-day nodes come before it.
    static let firstDayStage = 3
    /// Survived the 7-day review, next gap is 15 days.
    static let masteredStage = 7
    /// 1.x stages counted day-long gaps only.
    static let legacyStageOffset = 3
    /// A forgotten word is relearned within a day at the latest.
    static let relearnStage = 3
    /// Estimated retention at the moment a review falls due.
    static let dueRetention = 0.8

    static func clamp(_ stage: Int) -> Int { min(max(stage, 0), maxStage) }

    // MARK: Scheduling

    /// Schedule for a word that was just learned.
    static func initial(learnedAt date: Date) -> ReviewState {
        ReviewState(stage: 0, dueAt: dueDate(after: date, stage: 0), lastReviewedAt: date)
    }

    /// Default for words learned before scheduling existed (1.0): due the day after learning.
    static func legacyDefault(learnedOn day: String) -> ReviewState {
        let start = Calendar.current.startOfDay(for: DayKey.date(from: day) ?? Date())
        return ReviewState(stage: firstDayStage, dueAt: dueDate(after: start, stage: firstDayStage), lastReviewedAt: start)
    }

    static func next(after state: ReviewState, grade: ReviewGrade, at now: Date) -> ReviewState {
        let elapsed = now.timeIntervalSince(state.anchor)
        // Stage whose gap the recall has already outlasted (credit for overdue reviews).
        let earned = (nodes.lastIndex { $0.interval <= elapsed }).map { $0 + 1 } ?? 0

        switch grade {
        case .remembered:
            // Answering a word that isn't due yet (e.g. retaking a session) must not fast-track it.
            guard isDue(state, at: now) else { return state }
            let stage = clamp(max(state.stage + 1, earned))
            return ReviewState(stage: stage, dueAt: dueDate(after: now, stage: stage), lastReviewedAt: now, lapses: state.lapses)
        case .fuzzy:
            guard isDue(state, at: now) else { return state }
            let stage = clamp(max(state.stage, earned - 1))
            return ReviewState(stage: stage, dueAt: dueDate(after: now, stage: stage), lastReviewedAt: now, lapses: state.lapses)
        case .forgot:
            // Keep most of the long-term strength, but relearn within a day.
            let stage = max(0, state.stage - 2)
            let gapStage = min(stage, relearnStage)
            return ReviewState(stage: stage, dueAt: dueDate(after: now, stage: gapStage), lastReviewedAt: now, lapses: state.lapses + 1)
        }
    }

    /// Short gaps are exact; day-long gaps land at the start of the target day so the word
    /// can be reviewed any time that day.
    static func dueDate(after date: Date, stage: Int) -> Date {
        let node = nodes[clamp(stage)]
        guard let days = node.days else { return date.addingTimeInterval(node.interval) }
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: date)) ?? date.addingTimeInterval(node.interval)
    }

    /// Schedule for a record, falling back to the default for words learned before scheduling existed.
    static func state(for record: StudyRecord, in states: [String: ReviewState]) -> ReviewState {
        states[record.wordKey] ?? legacyDefault(learnedOn: record.date)
    }

    static func isDue(_ state: ReviewState, at now: Date) -> Bool {
        state.dueAt <= now
    }

    // MARK: Retention

    /// Estimated share remembered: 100% right after a review, `dueRetention` when due, lower after.
    static func retention(_ state: ReviewState, at now: Date) -> Double {
        let gap = max(state.dueAt.timeIntervalSince(state.anchor), minute)
        let elapsed = max(now.timeIntervalSince(state.anchor), 0)
        return pow(dueRetention, elapsed / gap)
    }

    /// Ebbinghaus (1885) savings curve without any review: b = 184 / ((log10 t)^1.25 + 1.84), t in minutes.
    static func ebbinghausRetention(minutes t: Double) -> Double {
        guard t > 1 else { return 1 }
        return min(1, 1.84 / (pow(log10(t), 1.25) + 1.84))
    }

    // MARK: Mastery

    static func mastery(of stage: Int) -> Mastery {
        switch stage {
        case ..<firstDayStage: return .new
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
