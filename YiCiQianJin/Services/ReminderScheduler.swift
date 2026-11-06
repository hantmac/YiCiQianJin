import Foundation
import UserNotifications

/// Local daily reminders. One-off notifications are scheduled for the next week instead of a
/// repeating trigger, so today's reminder can be skipped once the user has already studied.
enum ReminderScheduler {
    private static let prefix = "yiciqianjin.reminder."
    private static let daysAhead = 7

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func reschedule(hour: Int, minute: Int, studiedToday: Bool, streak: Int, now: Date = Date()) async {
        await cancelAll()
        guard await isAuthorized() else { return }

        let center = UNUserNotificationCenter.current()
        let cal = Calendar.current
        for offset in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: now),
                  let fire = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { continue }
            if offset == 0 && studiedToday { continue }

            let content = UNMutableNotificationContent()
            content.title = "小象在等你背今天的单词"
            content.body = message(dayOffset: offset, streak: streak)
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: prefix + "\(offset)", content: content, trigger: trigger))
        }
    }

    private static func message(dayOffset: Int, streak: Int) -> String {
        // The streak value is only accurate for the first upcoming reminder.
        if dayOffset <= 1 && streak > 0 {
            return "已连续学习 \(streak) 天，花 1 分钟背个词，别让连胜断掉 🔥"
        }
        let lines = [
            "一天一词，一年就是 365 个词。今天这个词你认识吗？",
            "先考昨天的词，再解锁今天的新词，1 分钟就够。",
            "温故而知新：有单词到了复习时间，来巩固一下吧。",
            "今天还没赚到「千金」，来背一个词吧 ✨",
        ]
        return lines[dayOffset % lines.count]
    }
}
