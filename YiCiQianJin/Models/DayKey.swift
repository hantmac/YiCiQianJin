import Foundation

/// Day identifiers stored as "yyyy-MM-dd" strings (the format already persisted in user data).
enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        formatter.date(from: key)
    }

    static func today(_ now: Date = Date()) -> String {
        string(from: now)
    }

    /// Returns the key `days` after `key` (negative values go back in time).
    static func adding(_ days: Int, to key: String) -> String {
        guard let date = date(from: key),
              let shifted = Calendar.current.date(byAdding: .day, value: days, to: date) else {
            return key
        }
        return string(from: shifted)
    }

    /// Whole days from `from` to `to` (positive when `to` is later).
    static func distance(from: String, to: String) -> Int {
        guard let a = date(from: from), let b = date(from: to) else { return 0 }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }
}
