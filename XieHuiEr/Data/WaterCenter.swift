import Foundation
import Observation

/// 喝水记录的界面状态（plan.md §2.4）：今天的杯数、距上次喝水、5 秒内的撤销窗口。
/// 界面每秒刷新时调用 `refreshIfNeeded`，只有跨天才重新查库。
@MainActor
@Observable
final class WaterCenter {
    private(set) var todayCount: Int
    private(set) var lastDrinkAt: Date?
    /// 点过「+1 杯」后 5 秒内可以撤销
    private(set) var undoDeadline: Date?

    @ObservationIgnored private let store: DataStore
    @ObservationIgnored private var lastAdded: WaterRecord?
    @ObservationIgnored private var currentDay: Date

    init(store: DataStore, now: Date = Date(), calendar: Calendar = .current) {
        self.store = store
        currentDay = calendar.startOfDay(for: now)
        todayCount = store.waterCount(from: currentDay, to: Self.nextDay(currentDay, calendar: calendar))
        lastDrinkAt = store.lastDrinkAt()
    }

    func canUndo(now: Date) -> Bool {
        guard let undoDeadline else { return false }
        return now <= undoDeadline
    }

    /// 主循环每秒调用一次；跨天后重新查库
    func refreshIfNeeded(now: Date, calendar: Calendar) {
        guard currentDay != calendar.startOfDay(for: now) else { return }
        refresh(now: now, calendar: calendar)
    }

    /// 重新从数据库读取（跨天、删除记录后使用）
    func refresh(now: Date, calendar: Calendar) {
        currentDay = calendar.startOfDay(for: now)
        todayCount = store.waterCount(from: currentDay, to: Self.nextDay(currentDay, calendar: calendar))
        lastDrinkAt = store.lastDrinkAt()
    }

    /// 记录一杯水，并开启 5 秒的撤销窗口
    func drink(now: Date, calendar: Calendar) {
        refreshIfNeeded(now: now, calendar: calendar)
        lastAdded = store.addWater(at: now)
        todayCount += 1
        lastDrinkAt = now
        undoDeadline = now.addingTimeInterval(5)
    }

    /// 撤销刚才那一条；窗口之外不做任何事
    func undo(now: Date) {
        guard canUndo(now: now), let lastAdded else { return }
        store.delete(lastAdded)
        self.lastAdded = nil
        undoDeadline = nil
        todayCount = max(0, todayCount - 1)
        lastDrinkAt = store.lastDrinkAt()
    }

    private static func nextDay(_ day: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 60 * 60)
    }
}
