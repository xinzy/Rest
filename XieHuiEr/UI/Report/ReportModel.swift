import Foundation
import Observation

/// 报表窗口的数据（plan.md §2.5）。只在打开窗口、切换分段或选择日期时查库，不跟主循环每秒刷新。
@MainActor
@Observable
final class ReportModel {
    /// 顶部的两个分段：喝水、休息
    enum Tab: Hashable {
        case water
        case rest
    }

    /// 时间范围
    enum Span: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30

        var days: Int { rawValue }

        var title: String {
            self == .week ? "近 7 天" : "近 30 天"
        }

        var id: Int { rawValue }
    }

    var tab: Tab = .water {
        didSet { reload() }
    }
    var span: Span = .week {
        didSet { reload() }
    }

    /// 明细区当前选中的一天（本地 0 点）
    private(set) var selectedDay: Date
    /// 今天的本地 0 点；跨天后随 reload 更新
    private(set) var today: Date
    private(set) var waterDays: [WaterDayCount] = []
    private(set) var waterRecords: [WaterRecord] = []
    private(set) var breakDays: [BreakDaySummary] = []
    private(set) var lastDrinkAt: Date?

    @ObservationIgnored private let store: DataStore
    @ObservationIgnored private let waterGoal: () -> Int
    @ObservationIgnored private let onRecordsChanged: () -> Void
    @ObservationIgnored private let calendar: Calendar

    init(
        store: DataStore,
        waterGoal: @escaping () -> Int,
        onRecordsChanged: @escaping () -> Void,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.store = store
        self.waterGoal = waterGoal
        self.onRecordsChanged = onRecordsChanged
        self.calendar = calendar
        let startOfToday = calendar.startOfDay(for: now)
        today = startOfToday
        selectedDay = startOfToday
        reload(now: now)
    }

    var waterReport: WaterReport {
        WaterReport(days: waterDays, goal: waterGoal())
    }

    var breakReport: BreakReport {
        BreakReport(days: breakDays)
    }

    /// 范围内最早的一天，明细区不能再往前
    var earliestDay: Date {
        calendar.date(byAdding: .day, value: -(span.days - 1), to: today) ?? today
    }

    var canGoEarlier: Bool {
        selectedDay > earliestDay
    }

    var canGoLater: Bool {
        selectedDay < today
    }

    /// 重新查库；窗口成为前台、切换分段、删除记录后调用
    func reload(now: Date = Date()) {
        today = calendar.startOfDay(for: now)
        waterDays = store.waterCounts(lastDays: span.days, now: now, calendar: calendar)
        lastDrinkAt = store.lastDrinkAt()

        let first = earliestDay
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let days = (0..<span.days).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
        breakDays = ReportStats.breakDays(days: days, events: store.breakRecords(from: first, to: end), calendar: calendar)

        if selectedDay < first || selectedDay > today {
            selectedDay = today
        }
        loadSelectedDayRecords()
    }

    /// 点选柱状图或用左右箭头切换日期
    func select(day: Date) {
        let normalized = calendar.startOfDay(for: day)
        guard normalized >= earliestDay, normalized <= today else { return }
        selectedDay = normalized
        loadSelectedDayRecords()
    }

    func shiftDay(by days: Int) {
        guard let target = calendar.date(byAdding: .day, value: days, to: selectedDay) else { return }
        select(day: target)
    }

    /// 删除一条喝水记录，概览、图表和明细一起重算，面板的今日杯数也跟着刷新
    func delete(_ record: WaterRecord) {
        store.delete(record)
        onRecordsChanged()
        reload()
    }

    private func loadSelectedDayRecords() {
        guard let end = calendar.date(byAdding: .day, value: 1, to: selectedDay) else {
            waterRecords = []
            return
        }
        waterRecords = store.waterRecords(from: selectedDay, to: end)
    }
}
