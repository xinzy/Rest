import Foundation
import Testing
@testable import XieHuiEr

/// 菜单栏图标的样式（plan.md §3.1）和暂停菜单的选项（原型 03 ①）
struct RingIconStyleTests {
    private let t0 = TestCalendar.date(2026, 10, 27, 10, 24)

    private func style(_ scheduler: BreakScheduler, at seconds: TimeInterval) -> RingIconStyle {
        RingIconStyle(state: scheduler.state, settings: scheduler.settings, now: t0 + seconds)
    }

    @Test func workingProgressShrinksAndRoundsUpToPercent() {
        let scheduler = BreakScheduler(settings: BreakSettings(), now: t0)

        #expect(style(scheduler, at: 0) == .progress(1))
        #expect(style(scheduler, at: 360) == .progress(0.8))
        #expect(style(scheduler, at: 361) == .progress(0.8), "剩余 79.94% 向上取整")
        #expect(style(scheduler, at: 1790) == .progress(0.01))
    }

    @Test func otherStates() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(now: t0 + 1770, isInMeeting: { false })
        #expect(style(scheduler, at: 1770) == .dot)

        var meeting = BreakScheduler(settings: BreakSettings(), now: t0)
        meeting.tick(now: t0 + 1770, isInMeeting: { true })
        #expect(style(meeting, at: 1770) == .dot)

        scheduler.startNow(now: t0 + 1775)
        #expect(style(scheduler, at: 1775) == .filled)

        var paused = BreakScheduler(settings: BreakSettings(), now: t0)
        paused.pause(until: nil, now: t0)
        #expect(style(paused, at: 0) == .paused)

        var away = BreakScheduler(settings: BreakSettings(), now: t0)
        away.userAway(since: t0, now: t0)
        #expect(style(away, at: 0) == .muted)

        var offHours = BreakScheduler(settings: BreakSettings(), now: t0)
        offHours.workTimeChanged(.off(nextStart: nil), now: t0)
        #expect(style(offHours, at: 0) == .muted)
    }
}

struct PauseOptionTests {
    private let calendar = TestCalendar.shanghai
    private let now = TestCalendar.date(2026, 10, 27, 10, 24)

    @Test func untilTimes() {
        #expect(PauseOption.thirtyMinutes.until(now: now, calendar: calendar) == now + 1800)
        #expect(PauseOption.oneHour.until(now: now, calendar: calendar) == now + 3600)
        #expect(PauseOption.untilTomorrow.until(now: now, calendar: calendar) == TestCalendar.date(2026, 10, 28, 0, 0))
        #expect(PauseOption.untilResumed.until(now: now, calendar: calendar) == nil)
    }

    @Test func menuDetails() {
        #expect(PauseOption.thirtyMinutes.detail(now: now, calendar: calendar) == "到 10:54")
        #expect(PauseOption.oneHour.detail(now: now, calendar: calendar) == "到 11:24")
        #expect(PauseOption.untilTomorrow.detail(now: now, calendar: calendar) == "次日 0 点")
        #expect(PauseOption.untilResumed.detail(now: now, calendar: calendar) == nil)
    }
}
