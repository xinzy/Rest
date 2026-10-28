import Foundation
import Testing
@testable import XieHuiEr

/// 报表的纯逻辑（plan.md §2.5）。示例数据与原型 08、09 相同：2026-10-27 是周二。
struct ReportStatsTests {
    private let calendar = TestCalendar.shanghai

    private func day(_ day: Int) -> Date {
        calendar.startOfDay(for: TestCalendar.date(2026, 10, day, 12, 0))
    }

    private func waterDays(_ counts: [Int], endingOn endDay: Int = 27) -> [WaterDayCount] {
        counts.enumerated().map { index, count in
            WaterDayCount(day: day(endDay - counts.count + 1 + index), count: count)
        }
    }

    private func event(_ dayOfMonth: Int, _ hour: Int, _ minute: Int, _ outcome: BreakOutcome) -> BreakRecord {
        BreakRecord(at: TestCalendar.date(2026, 10, dayOfMonth, hour, minute), kind: .short, outcome: outcome, trigger: .scheduled)
    }

    // MARK: - 喝水

    @Test func waterOverviewMatchesPrototype() {
        let report = WaterReport(days: waterDays([6, 8, 9, 5, 8, 4, 3]), goal: 8)

        #expect(report.todayCount == 3)
        #expect(report.total == 43)
        #expect(report.averageText == "6.1")
        #expect(report.achievedDays == 3)
        #expect(report.todayUnit == "/ 8 杯")
        #expect(report.totalSubtitle == "近 7 天共 43 杯")
        #expect(report.achievedPrimary == "3")
        #expect(report.achievedUnit == "/ 7 天")
        #expect(report.achievedSubtitle == "每日目标 8 杯")
    }

    @Test func waterWithoutGoalShowsNoTarget() {
        let report = WaterReport(days: waterDays([6, 8, 9, 5, 8, 4, 3]), goal: 0)

        #expect(report.achievedDays == 0)
        #expect(report.todayUnit == "杯")
        #expect(report.achievedPrimary == "—")
        #expect(report.achievedUnit == "未设目标")
        #expect(report.achievedSubtitle == "每日目标未设置")
    }

    @Test func waterAverageUsesOneDecimal() {
        // 7 天共 43 杯：6.142857… → 6.1
        #expect(WaterReport(days: waterDays([6, 8, 9, 5, 8, 4, 3]), goal: 8).averageText == "6.1")
        // 两天共 5 杯：2.5
        #expect(WaterReport(days: waterDays([2, 3]), goal: 8).averageText == "2.5")
    }

    @Test func waterEmptyRangeIsZero() {
        let report = WaterReport(days: [], goal: 8)
        #expect(report.todayCount == 0)
        #expect(report.total == 0)
        #expect(report.averageText == "0.0")
        #expect(report.achievedPrimary == "0")
        #expect(report.achievedUnit == "/ 0 天")
    }

    @Test func waterChartMaxLeavesHeadroomAndIncludesGoal() {
        // 最高 9 杯 → 9.9
        #expect(abs(WaterReport(days: waterDays([6, 8, 9]), goal: 8).chartMax - 9.9) < 0.0001)
        // 目标比最高的柱子还高时按目标算
        #expect(abs(WaterReport(days: waterDays([1, 2]), goal: 20).chartMax - 22) < 0.0001)
        // 完全没有数据时也不为 0
        #expect(WaterReport(days: [], goal: 0).chartMax == 1)
    }

    // MARK: - 日期与时间文案

    @Test func dateTextIncludesWeekday() {
        #expect(ReportStats.dateText(day(27), calendar: calendar) == "10月27日 周二")
        #expect(ReportStats.dateText(day(28), calendar: calendar) == "10月28日 周三")
        #expect(ReportStats.weekdayText(day(25), calendar: calendar) == "周日")
    }

    @Test func monthDayTextPadsDay() {
        #expect(ReportStats.monthDayText(day(27), calendar: calendar) == "10-27")
        #expect(ReportStats.monthDayText(day(5), calendar: calendar) == "10-05")
    }

    @Test func timeTextUsesTwoDigits() {
        #expect(ReportStats.timeText(TestCalendar.date(2026, 10, 27, 9, 4), calendar: calendar) == "09:04")
        #expect(ReportStats.timeText(TestCalendar.date(2026, 10, 27, 23, 59), calendar: calendar) == "23:59")
    }

    @Test func percentRoundsToWholeNumber() {
        #expect(ReportStats.percentText(13.0 / 14.0) == "93%")
        #expect(ReportStats.percentText(2.0 / 3.0) == "67%")
        #expect(ReportStats.percentText(1) == "100%")
        #expect(ReportStats.percentText(nil) == "—")
        #expect(ReportStats.percentNumberText(nil) == nil)
    }

    // MARK: - 休息

    @Test func breakDayWithoutRecordsUsesDash() {
        let summary = BreakDaySummary(day: day(25))
        #expect(summary.rate == nil)
        #expect(summary.rateText == "—")
        #expect(summary.isOff)
    }

    @Test func breakDaysGroupByLocalDay() {
        let events = [
            event(26, 23, 50, .completed),
            event(27, 0, 10, .skipped),
            event(27, 15, 0, .postponed),
            event(27, 16, 0, .postponed),
            event(27, 17, 0, .autoDeferred),
            event(28, 9, 0, .completed),
            // 区间外的记录不参与统计
            event(25, 9, 0, .completed),
        ]
        let days = [day(26), day(27), day(28)]
        let summaries = ReportStats.breakDays(days: days, events: events, calendar: calendar)

        #expect(summaries.map(\.completed) == [1, 0, 1])
        #expect(summaries.map(\.skipped) == [0, 1, 0])
        #expect(summaries.map(\.postponed) == [0, 2, 0])
        #expect(summaries.map(\.autoDeferred) == [0, 1, 0])
        #expect(summaries.map(\.isOff) == [false, false, false])
        #expect(summaries[1].rateText == "0%")
        #expect(summaries[2].rateText == "100%")
    }

    @Test func breakDaysKeepEmptyDaysInRange() {
        let summaries = ReportStats.breakDays(
            days: [day(25), day(26), day(27)],
            events: [event(27, 10, 0, .completed)],
            calendar: calendar
        )

        #expect(summaries.count == 3)
        #expect(summaries[0].isOff)
        #expect(summaries[1].isOff)
        #expect(!summaries[2].isOff)
    }

    @Test func breakReportMatchesPrototype() {
        let completed = [12, 14, 11, 0, 0, 13, 2]
        let skipped = [2, 1, 3, 0, 0, 1, 0]
        let postponed = [3, 2, 4, 0, 0, 2, 1]
        let autoDeferred = [1, 2, 0, 0, 0, 3, 0]
        let days = (0..<7).map { index in
            BreakDaySummary(
                day: day(21 + index),
                completed: completed[index],
                skipped: skipped[index],
                postponed: postponed[index],
                autoDeferred: autoDeferred[index]
            )
        }
        let report = BreakReport(days: days)

        #expect(report.completed == 52)
        #expect(report.skipped == 7)
        #expect(report.postponed == 12)
        #expect(report.autoDeferred == 6)
        #expect(report.rateNumberText == "88")
        #expect(report.rateUnit == "%")
        #expect(report.spanSubtitle == "近 7 天")
        #expect(report.postponedSubtitle == "另有开会自动推迟 6 次")
        // 明细表最新的一天在最上面
        #expect(report.newestFirst.first?.day == day(27))
        #expect(report.newestFirst.first?.rateText == "100%")
        #expect(report.newestFirst.last?.day == day(21))
    }

    @Test func breakReportWithoutRecordsHasNoRate() {
        let report = BreakReport(days: [BreakDaySummary(day: day(26)), BreakDaySummary(day: day(27))])
        #expect(report.rateNumberText == "—")
        #expect(report.rateUnit == "")
        #expect(report.postponedSubtitle == "另有开会自动推迟 0 次")
    }
}
