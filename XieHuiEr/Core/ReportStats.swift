import Foundation

/// 报表的文案和汇总（plan.md §2.5）。纯逻辑，不依赖界面，有单元测试。
enum ReportStats {
    private static let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    /// 「10月27日 周二」
    static func dateText(_ day: Date, calendar: Calendar) -> String {
        "\(calendar.component(.month, from: day))月\(calendar.component(.day, from: day))日 \(weekdayText(day, calendar: calendar))"
    }

    /// 「周二」
    static func weekdayText(_ day: Date, calendar: Calendar) -> String {
        weekdayNames[calendar.component(.weekday, from: day) - 1]
    }

    /// 图表 x 轴第二行的「10-27」
    static func monthDayText(_ day: Date, calendar: Calendar) -> String {
        String(format: "%d-%02d", calendar.component(.month, from: day), calendar.component(.day, from: day))
    }

    /// 「09:04」
    static func timeText(_ time: Date, calendar: Calendar) -> String {
        String(format: "%02d:%02d", calendar.component(.hour, from: time), calendar.component(.minute, from: time))
    }

    /// 完成率四舍五入到整数；没有可算的分母时显示「—」
    static func percentText(_ rate: Double?) -> String {
        guard let number = percentNumberText(rate) else { return "—" }
        return number + "%"
    }

    /// 概览卡里的大号数字，后面单独跟一个小号「%」；没有分母时为 nil
    static func percentNumberText(_ rate: Double?) -> String? {
        guard let rate else { return nil }
        return String(Int((rate * 100).rounded()))
    }

    /// 把区间内的休息记录按本地 0 点分组；days 之外的记录忽略
    static func breakDays(days: [Date], events: [BreakRecord], calendar: Calendar) -> [BreakDaySummary] {
        var summaries: [Date: BreakDaySummary] = [:]
        for day in days {
            summaries[day] = BreakDaySummary(day: day)
        }
        for event in events {
            let day = calendar.startOfDay(for: event.at)
            guard var summary = summaries[day] else { continue }
            switch event.outcome {
            case .completed: summary.completed += 1
            case .skipped: summary.skipped += 1
            case .postponed: summary.postponed += 1
            case .autoDeferred: summary.autoDeferred += 1
            }
            summaries[day] = summary
        }
        return days.compactMap { summaries[$0] }
    }
}

/// 喝水页概览卡的内容：今日、日均、达标
struct WaterReport: Equatable, Sendable {
    /// 从早到晚，最后一个是今天
    let days: [WaterDayCount]
    /// 0 表示不设目标
    let goal: Int

    var todayCount: Int { days.last?.count ?? 0 }
    var total: Int { days.reduce(0) { $0 + $1.count } }
    var average: Double {
        days.isEmpty ? 0 : Double(total) / Double(days.count)
    }
    var averageText: String {
        String(format: "%.1f", average)
    }
    /// 达到每日目标的天数；不设目标时不算达标
    var achievedDays: Int {
        guard goal > 0 else { return 0 }
        return days.filter { $0.count >= goal }.count
    }

    /// 「/ 8 杯」，不设目标时是「杯」
    var todayUnit: String {
        goal > 0 ? "/ \(goal) 杯" : "杯"
    }
    /// 「近 7 天共 43 杯」
    var totalSubtitle: String {
        "近 \(days.count) 天共 \(total) 杯"
    }
    var achievedPrimary: String {
        goal > 0 ? "\(achievedDays)" : "—"
    }
    var achievedUnit: String {
        goal > 0 ? "/ \(days.count) 天" : "未设目标"
    }
    var achievedSubtitle: String {
        goal > 0 ? "每日目标 \(goal) 杯" : "每日目标未设置"
    }

    /// 图表 y 轴上限：最高的一根柱或目标线，再留 10% 余量
    var chartMax: Double {
        let peak = max(days.map(\.count).max() ?? 0, goal)
        return max(Double(peak) * 1.1, 1)
    }
}

/// 一天的休息次数，用于堆叠柱状图和明细表
struct BreakDaySummary: Equatable, Sendable {
    let day: Date
    var completed = 0
    var skipped = 0
    var postponed = 0
    var autoDeferred = 0

    /// 柱子里显示的总数（推迟不算一次休息，所以不进柱子）
    var total: Int { completed + skipped }

    /// 完成率 = 完成 ÷（完成 + 跳过）；分母为 0 时为 nil
    var rate: Double? {
        let denominator = completed + skipped
        guard denominator > 0 else { return nil }
        return Double(completed) / Double(denominator)
    }

    var rateText: String {
        ReportStats.percentText(rate)
    }

    /// 这一天没有任何记录（周末、没开电脑）时整行灰显
    var isOff: Bool {
        completed + skipped + postponed + autoDeferred == 0
    }
}

/// 休息页概览卡的内容和明细表的行
struct BreakReport: Equatable, Sendable {
    /// 从早到晚
    let days: [BreakDaySummary]

    var completed: Int { days.reduce(0) { $0 + $1.completed } }
    var skipped: Int { days.reduce(0) { $0 + $1.skipped } }
    var postponed: Int { days.reduce(0) { $0 + $1.postponed } }
    var autoDeferred: Int { days.reduce(0) { $0 + $1.autoDeferred } }

    var rate: Double? {
        let denominator = completed + skipped
        guard denominator > 0 else { return nil }
        return Double(completed) / Double(denominator)
    }
    var rateNumberText: String {
        ReportStats.percentNumberText(rate) ?? "—"
    }
    var rateUnit: String {
        rate == nil ? "" : "%"
    }

    var spanSubtitle: String {
        "近 \(days.count) 天"
    }
    var postponedSubtitle: String {
        "另有开会自动推迟 \(autoDeferred) 次"
    }

    /// 明细表最新的一天在最上面
    var newestFirst: [BreakDaySummary] {
        days.reversed()
    }

    /// 堆叠柱的 y 轴上限：最多的一天再留 10% 余量
    var chartMax: Double {
        let peak = days.map(\.total).max() ?? 0
        return max(Double(peak) * 1.15, 1)
    }
}
