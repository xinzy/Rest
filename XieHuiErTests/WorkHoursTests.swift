import Foundation
import Testing
@testable import XieHuiEr

/// 工作时间判定（plan.md §2.2、§3.2）。日期都在 2026 年 10–11 月：
/// 10-26 周一、10-27 周二、10-30 周五、10-31 周六、11-01 周日、11-02 周一。
struct WorkHoursTests {
    private let calendar = TestCalendar.shanghai
    private let workHours = WorkHours()

    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute, second: second
        ))!
    }

    private func state(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> WorkTime {
        workHours.state(now: date(month, day, hour, minute), calendar: calendar)
    }

    @Test func insideWorkTime() {
        #expect(state(10, 27, 10, 0) == .on)
    }

    @Test func startIsInclusive() {
        #expect(state(10, 27, 9, 0) == .on)
    }

    @Test func endIsExclusive() {
        let expected = WorkTime.off(nextStart: date(10, 28, 9, 0))
        #expect(state(10, 27, 19, 0) == expected)
        #expect(state(10, 27, 18, 59) == .on)
    }

    @Test func beforeStartWaitsForToday() {
        let expected = WorkTime.off(nextStart: date(10, 27, 9, 0))
        #expect(state(10, 27, 8, 59) == expected)
    }

    @Test func weekendWaitsForMonday() {
        let expected = WorkTime.off(nextStart: date(11, 2, 9, 0))
        #expect(state(10, 31, 10, 0) == expected)
        #expect(state(11, 1, 10, 0) == expected)
    }

    @Test func fridayEveningWaitsForMonday() {
        let expected = WorkTime.off(nextStart: date(11, 2, 9, 0))
        #expect(state(10, 30, 20, 0) == expected)
    }

    @Test func singleWorkdayWaitsAWeek() {
        var hours = WorkHours()
        hours.days = [2]
        let monday = date(10, 26, 10, 0)

        #expect(hours.state(now: monday, calendar: calendar) == .on)
        #expect(hours.state(now: date(10, 27, 10, 0), calendar: calendar) == .off(nextStart: date(11, 2, 9, 0)))
        #expect(hours.state(now: date(10, 26, 20, 0), calendar: calendar) == .off(nextStart: date(11, 2, 9, 0)))
    }

    @Test func withoutWorkdaysThereIsNoNextStart() {
        var hours = WorkHours()
        hours.days = []

        #expect(hours.state(now: date(10, 27, 10, 0), calendar: calendar) == .off(nextStart: nil))
        #expect(hours.nextStart(now: date(10, 27, 10, 0), calendar: calendar) == nil)
    }

    @Test func disabledIsAlwaysOn() {
        var hours = WorkHours()
        hours.enabled = false

        #expect(hours.state(now: date(10, 31, 3, 0), calendar: calendar) == .on)
    }

    @Test func summaryUsesRangesForThreeOrMoreDays() {
        #expect(workHours.summary == "周一至周五 09:00–19:00")

        var hours = WorkHours()
        hours.days = [1, 2, 3, 4, 5, 6, 7]
        #expect(hours.summary == "周一至周日 09:00–19:00")

        hours.days = [2, 4]
        #expect(hours.summary == "周一、周三 09:00–19:00")

        hours.days = [2, 4, 5, 6]
        #expect(hours.summary == "周一、周三至周五 09:00–19:00")

        hours.days = []
        #expect(hours.summary == "未设置工作日")
    }

    @Test func summaryShowsCustomTime() {
        var hours = WorkHours()
        hours.startMinutes = 8 * 60 + 30
        hours.endMinutes = 18 * 60 + 5

        #expect(hours.summary == "周一至周五 08:30–18:05")
    }

    @Test func rangeMustNotCrossMidnight() {
        var hours = WorkHours()
        #expect(hours.isValid)

        hours.startMinutes = 19 * 60
        hours.endMinutes = 9 * 60
        #expect(!hours.isValid)

        hours.startMinutes = 9 * 60
        hours.endMinutes = 9 * 60
        #expect(!hours.isValid)

        hours.endMinutes = 24 * 60
        #expect(!hours.isValid)
    }
}
