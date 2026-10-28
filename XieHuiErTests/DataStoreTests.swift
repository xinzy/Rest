import Foundation
import Testing
@testable import XieHuiEr

/// 数据层（plan.md §2.4、§5.3）：用内存数据库。日期在 2026-10-26 周一至 10-28 周三。
@MainActor
struct DataStoreTests {
    private let calendar = TestCalendar.shanghai
    private let store = DataStore(container: DataStore.makeContainer(inMemory: true))

    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        TestCalendar.date(2026, month, day, hour, minute)
    }

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.startOfDay(for: date(month, day, 12))
    }

    @Test func todayCountUsesLocalMidnight() {
        store.addWater(at: date(10, 27, 0, 5))
        store.addWater(at: date(10, 27, 9, 30))

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day(10, 27))!
        #expect(store.waterCount(from: day(10, 27), to: tomorrow) == 2)
        #expect(store.waterCount(from: day(10, 26), to: day(10, 27)) == 0)
    }

    @Test func waterCountsGroupByDay() {
        store.addWater(at: date(10, 26, 23, 50))
        store.addWater(at: date(10, 27, 0, 10))
        store.addWater(at: date(10, 27, 15, 0))
        store.addWater(at: date(10, 28, 8, 0))

        let counts = store.waterCounts(lastDays: 3, now: date(10, 28, 12), calendar: calendar)

        #expect(counts.map(\.count) == [1, 2, 1])
        #expect(counts.map(\.day) == [day(10, 26), day(10, 27), day(10, 28)])
    }

    @Test func lastDrinkAtFollowsDeletion() {
        let first = store.addWater(at: date(10, 27, 9))
        let second = store.addWater(at: date(10, 27, 10))
        #expect(store.lastDrinkAt() == date(10, 27, 10))

        // 删掉最新那条后回到上一条
        store.delete(second)
        #expect(store.lastDrinkAt() == date(10, 27, 9))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day(10, 27))!
        #expect(store.waterCount(from: day(10, 27), to: tomorrow) == 1)

        store.delete(first)
        #expect(store.lastDrinkAt() == nil)
    }

    @Test func breakEventStoresEnumNames() {
        store.addBreakEvent(BreakRecord(at: date(10, 27, 10), kind: .long, outcome: .autoDeferred, trigger: .scheduled))
        store.addBreakEvent(BreakRecord(at: date(10, 27, 11), kind: .short, outcome: .skipped, trigger: .manual))

        let events = store.breakEvents()
        #expect(events.count == 2)
        #expect(events[0].kind == "long")
        #expect(events[0].type == "autoDeferred")
        #expect(events[0].trigger == "scheduled")
        #expect(events[1].kind == "short")
        #expect(events[1].type == "skipped")
        #expect(events[1].trigger == "manual")
    }

    @Test func drinkAndUndoWithinFiveSeconds() {
        let center = WaterCenter(store: store, now: date(10, 27, 9), calendar: calendar)
        #expect(center.todayCount == 0)

        center.drink(now: date(10, 27, 9, 30), calendar: calendar)
        #expect(center.todayCount == 1)
        #expect(center.lastDrinkAt == date(10, 27, 9, 30))
        // 5 秒窗口内可以撤销（9:30:05 之前）
        #expect(center.canUndo(now: center.lastDrinkAt!.addingTimeInterval(3)))

        center.undo(now: center.lastDrinkAt!.addingTimeInterval(4))
        #expect(center.todayCount == 0)
        #expect(center.lastDrinkAt == nil)
        #expect(store.lastDrinkAt() == nil)
    }

    @Test func undoAfterWindowDoesNothing() {
        let center = WaterCenter(store: store, now: date(10, 27, 9), calendar: calendar)
        center.drink(now: date(10, 27, 9, 30), calendar: calendar)

        center.undo(now: date(10, 27, 9, 30).addingTimeInterval(6))
        #expect(center.todayCount == 1)
        #expect(store.lastDrinkAt() == date(10, 27, 9, 30))
    }

    @Test func countResetsOnNewDay() {
        store.addWater(at: date(10, 27, 23, 30))
        let center = WaterCenter(store: store, now: date(10, 27, 23, 40), calendar: calendar)
        #expect(center.todayCount == 1)

        center.refreshIfNeeded(now: date(10, 28, 0, 1), calendar: calendar)
        #expect(center.todayCount == 0)
        // 距上次喝水仍按昨天那杯算
        #expect(center.lastDrinkAt == date(10, 27, 23, 30))
    }

    @Test func waterRecordsAreSortedAndLimitedToRange() {
        store.addWater(at: date(10, 27, 15, 0))
        store.addWater(at: date(10, 27, 9, 0))
        store.addWater(at: date(10, 28, 8, 0))
        store.addWater(at: date(10, 26, 23, 50))

        let records = store.waterRecords(from: day(10, 27), to: day(10, 28))

        #expect(records.map(\.drankAt) == [date(10, 27, 9, 0), date(10, 27, 15, 0)])
    }

    @Test func breakRecordsMapEnumNamesAndRange() {
        store.addBreakEvent(BreakRecord(at: date(10, 27, 10), kind: .long, outcome: .completed, trigger: .scheduled))
        store.addBreakEvent(BreakRecord(at: date(10, 27, 9), kind: .short, outcome: .skipped, trigger: .manual))
        store.addBreakEvent(BreakRecord(at: date(10, 27, 11), kind: .short, outcome: .postponed, trigger: .scheduled))
        store.addBreakEvent(BreakRecord(at: date(10, 27, 12), kind: .short, outcome: .autoDeferred, trigger: .scheduled))
        store.addBreakEvent(BreakRecord(at: date(10, 25, 9), kind: .short, outcome: .completed, trigger: .scheduled))

        let records = store.breakRecords(from: day(10, 27), to: day(10, 28))

        #expect(records.count == 4)
        #expect(records.map(\.at) == [date(10, 27, 9), date(10, 27, 10), date(10, 27, 11), date(10, 27, 12)])
        #expect(records.map(\.outcome) == [.skipped, .completed, .postponed, .autoDeferred])
        #expect(records[1].kind == .long)
        #expect(records[0].trigger == .manual)
    }
}
