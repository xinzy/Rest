import Foundation

/// 喝水行的文案和高亮（原型 02、03 ⑥、06，plan.md §2.4）。纯逻辑，有单元测试。
struct WaterStatus: Equatable {
    var count: Int
    /// 0 表示不设目标
    var goal: Int
    var lastDrinkAt: Date?
    var now: Date
    var calendar: Calendar
    /// 点过「+1 杯」后的撤销截止时间
    var undoUntil: Date?

    var canUndo: Bool {
        guard let undoUntil else { return false }
        return now <= undoUntil
    }

    /// 距上次喝水满 2 小时（当天还没喝过也算）时高亮
    var isThirsty: Bool {
        guard let lastDrinkAt else { return true }
        return now.timeIntervalSince(lastDrinkAt) >= WaterStatus.thirstInterval
    }

    /// 面板第一行：「今日 3 / 8 杯」；不设目标时为「今日 3 杯」
    var countText: String {
        goal > 0 ? "今日 \(count) / \(goal) 杯" : "今日 \(count) 杯"
    }

    /// 进度条比例，超过目标时截到 1
    var barFraction: Double {
        guard goal > 0 else { return 0 }
        return min(Double(count) / Double(goal), 1)
    }

    /// 面板第三行：撤销提示、距上次喝水或「今天还没喝水」
    var metaText: String {
        canUndo ? "✓ 已记录 · 5 秒内可撤销" : hintText
    }

    /// 「距上次喝水 1 小时 20 分」「今天还没喝水」；遮罩按钮下方也用这句
    var hintText: String {
        guard let lastDrinkAt, isToday(lastDrinkAt) else { return "今天还没喝水" }
        return "距上次喝水 \(Self.elapsedText(now.timeIntervalSince(lastDrinkAt)))"
    }

    /// 遮罩上已记录时的按钮文案
    var overlayRecordedText: String {
        "✓ 已记录 · 今日 \(count) 杯"
    }

    /// 「1 小时 20 分」「45 分」「不到 1 分钟」
    static func elapsedText(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        if minutes < 1 { return "不到 1 分钟" }
        if minutes < 60 { return "\(minutes) 分" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) 小时" : "\(hours) 小时 \(rest) 分"
    }

    private static let thirstInterval: TimeInterval = 2 * 60 * 60

    private func isToday(_ time: Date) -> Bool {
        time >= calendar.startOfDay(for: now)
    }
}
