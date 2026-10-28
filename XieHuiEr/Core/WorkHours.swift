import Foundation

/// 工作时间段（plan.md §2.2、§4.3）。纯逻辑：当前时间和日历都由调用方传入。
/// 星期用 Calendar 的编号：1 = 周日 … 7 = 周六。
struct WorkHours: Equatable, Sendable {
    /// 只在工作时间提醒
    var enabled = true
    /// 勾选的工作日，默认周一到周五
    var days: Set<Int> = [2, 3, 4, 5, 6]
    /// 开始时间，从 0 点起的分钟数
    var startMinutes = 9 * 60
    /// 结束时间，从 0 点起的分钟数；不能跨午夜，必须晚于开始时间
    var endMinutes = 19 * 60

    var isValid: Bool {
        (0..<24 * 60).contains(startMinutes)
            && (0..<24 * 60).contains(endMinutes)
            && startMinutes < endMinutes
    }

    /// 现在是否在工作时间内；不在时给出下次开始的时间（没有勾选工作日时为 nil）
    func state(now: Date, calendar: Calendar) -> WorkTime {
        guard enabled else { return .on }
        guard !days.isEmpty else { return .off(nextStart: nil) }
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if let weekday = components.weekday, days.contains(weekday),
           minutes >= startMinutes, minutes < endMinutes {
            return .on
        }
        return .off(nextStart: nextStart(now: now, calendar: calendar))
    }

    /// 下次开始工作的时间：今天稍后、明天或更晚；最多往后找一周
    func nextStart(now: Date, calendar: Calendar) -> Date? {
        guard !days.isEmpty else { return nil }
        let today = calendar.startOfDay(for: now)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  days.contains(calendar.component(.weekday, from: day)),
                  let start = calendar.date(
                      bySettingHour: startMinutes / 60, minute: startMinutes % 60, second: 0, of: day
                  )
            else { continue }
            if offset > 0 || start > now {
                return start
            }
        }
        return nil
    }

    /// 面板第三行的说明：「周一至周五 09:00–19:00」；没有勾选工作日时为「未设置工作日」
    var summary: String {
        guard !days.isEmpty else { return "未设置工作日" }
        return "\(daySummary) \(Self.timeText(startMinutes))–\(Self.timeText(endMinutes))"
    }

    /// 工作组：连续的 3 天及以上用「至」，否则用「、」逐天列出
    private var daySummary: String {
        let names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let ordered = [2, 3, 4, 5, 6, 7, 1]
        let selected = ordered.map { days.contains($0) }
        var parts: [String] = []
        var index = 0
        while index < ordered.count {
            guard selected[index] else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < ordered.count, selected[end + 1] {
                end += 1
            }
            if end - index >= 2 {
                parts.append("\(names[index])至\(names[end])")
            } else {
                parts.append(contentsOf: names[index...end])
            }
            index = end + 1
        }
        return parts.joined(separator: "、")
    }

    private static func timeText(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
