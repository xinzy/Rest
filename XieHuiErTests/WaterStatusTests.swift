import Foundation
import Testing
@testable import XieHuiEr

/// 喝水行的文案和高亮（plan.md §2.4、§4.2）。日期都在 2026-10-27。
struct WaterStatusTests {
    private let calendar = TestCalendar.shanghai
    private let now = TestCalendar.date(2026, 10, 27, 14, 0)

    private func status(
        count: Int = 3,
        goal: Int = 8,
        lastDrinkAt: Date? = nil,
        undoUntil: Date? = nil
    ) -> WaterStatus {
        WaterStatus(count: count, goal: goal, lastDrinkAt: lastDrinkAt, now: now, calendar: calendar, undoUntil: undoUntil)
    }

    @Test func countTextShowsGoal() {
        #expect(status().countText == "今日 3 / 8 杯")
        #expect(status(count: 9).countText == "今日 9 / 8 杯")
    }

    @Test func countTextHidesGoalWhenZero() {
        #expect(status(goal: 0).countText == "今日 3 杯")
        #expect(status(goal: 0).barFraction == 0)
    }

    @Test func barFractionIsClamped() {
        #expect(status(count: 4, goal: 8).barFraction == 0.5)
        #expect(status(count: 12, goal: 8).barFraction == 1)
    }

    @Test func hintWhenNoDrinkToday() {
        // 从没喝过
        #expect(status().hintText == "今天还没喝水")
        // 昨天喝过也算今天还没喝
        let yesterday = TestCalendar.date(2026, 10, 26, 18, 0)
        #expect(status(lastDrinkAt: yesterday).hintText == "今天还没喝水")
    }

    @Test func hintShowsElapsedSinceLastDrink() {
        let last = TestCalendar.date(2026, 10, 27, 12, 40)
        #expect(status(lastDrinkAt: last).hintText == "距上次喝水 1 小时 20 分")
    }

    @Test func thirstyAfterTwoHours() {
        #expect(status().isThirsty)
        #expect(status(lastDrinkAt: now.addingTimeInterval(-2 * 60 * 60)).isThirsty)
        #expect(!status(lastDrinkAt: now.addingTimeInterval(-2 * 60 * 60 + 60)).isThirsty)
    }

    @Test func undoWindow() {
        #expect(!status().canUndo)
        #expect(status(undoUntil: now.addingTimeInterval(2)).canUndo)
        #expect(!status(undoUntil: now.addingTimeInterval(-1)).canUndo)
    }

    @Test func metaTextShowsUndoHintFirst() {
        let undo = status(lastDrinkAt: now.addingTimeInterval(-5 * 60), undoUntil: now.addingTimeInterval(3))
        #expect(undo.metaText == "✓ 已记录 · 5 秒内可撤销")
        #expect(status(lastDrinkAt: now.addingTimeInterval(-5 * 60)).metaText == "距上次喝水 5 分")
    }

    @Test func overlayRecordedText() {
        #expect(status(count: 2).overlayRecordedText == "✓ 已记录 · 今日 2 杯")
    }

    @Test func elapsedTextFormats() {
        #expect(WaterStatus.elapsedText(30) == "不到 1 分钟")
        #expect(WaterStatus.elapsedText(45 * 60) == "45 分")
        #expect(WaterStatus.elapsedText(2 * 60 * 60) == "2 小时")
        #expect(WaterStatus.elapsedText(90 * 60) == "1 小时 30 分")
    }
}
