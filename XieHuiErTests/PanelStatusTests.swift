import Foundation
import Testing
@testable import XieHuiEr

/// 面板状态区的文案（原型 02、03）。时间固定在 2026-10-27（周二）10:24:00，东八区。
struct PanelStatusTests {
    private let calendar = TestCalendar.shanghai
    private let t0 = TestCalendar.date(2026, 10, 27, 10, 24)

    private func status(_ scheduler: BreakScheduler, at seconds: TimeInterval = 0) -> PanelStatus {
        PanelStatus(scheduler: scheduler, now: t0 + seconds, calendar: calendar)
    }

    // MARK: 工作中

    @Test func workingShowsCountdownNextBreakAndRound() {
        let scheduler = BreakScheduler(settings: BreakSettings(), now: t0)

        let s = status(scheduler, at: 347)

        #expect(s.headline == .countdown("24:13"))
        #expect(s.subtitle == "后开始短休息（30 秒）")
        #expect(s.symbol == "eye")
        #expect(s.tint == .accent)
        #expect(abs(s.ringFraction - 1453.0 / 1800) < 1e-9)
        #expect(s.dots == RoundDots(total: 4, current: 0))
        #expect(s.roundsText == "第 1 / 4 轮")
        #expect(s.breakNowSubtitle == "短休息 · 30 秒")
        #expect(s.breakNowEnabled)
        #expect(s.secondTile == .pause(enabled: true, subtitle: "选择时长"))
    }

    @Test func countdownRoundsUpPartialSecondsAndShowsHoursWhenLong() {
        var settings = BreakSettings()
        settings.shortInterval = 120 * 60
        let scheduler = BreakScheduler(settings: settings, now: t0)

        #expect(status(scheduler, at: 0.4).headline == .countdown("2:00:00"))
        #expect(status(scheduler, at: 3600.5).headline == .countdown("1:00:00"))
        #expect(status(scheduler, at: 3601).headline == .countdown("59:59"))
    }

    @Test func roundBeforeLongBreakSaysNextRoundIsLong() {
        let scheduler = afterShortBreaks(2)

        let s = status(scheduler, at: 3 * 1830)

        #expect(s.dots == RoundDots(total: 4, current: 2))
        #expect(s.roundsText == "第 3 / 4 轮 · 下轮长休息")
    }

    @Test func longBreakRoundShowsLongTypeAndWalkSymbol() {
        let scheduler = afterShortBreaks(3)

        let s = status(scheduler, at: 3 * 1830)

        #expect(s.subtitle == "后开始长休息（5 分钟）")
        #expect(s.symbol == "figure.walk")
        #expect(s.roundsText == "第 4 / 4 轮 · 长休息")
        #expect(s.breakNowSubtitle == "长休息 · 5 分钟")
    }

    @Test func longBreakDisabledHidesDots() {
        var settings = BreakSettings()
        settings.longBreakEnabled = false
        let scheduler = BreakScheduler(settings: settings, now: t0)

        let s = status(scheduler)

        #expect(s.dots == nil)
        #expect(s.roundsText == "长休息已关闭")
    }

    @Test func warningLooksLikeWorking() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(now: t0 + 1775, isInMeeting: { false })

        let s = status(scheduler, at: 1775)

        #expect(s.headline == .countdown("00:25"))
        #expect(s.subtitle == "后开始短休息（30 秒）")
    }

    // MARK: 其他状态

    @Test func meetingDeferral() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(now: t0 + 1770, isInMeeting: { true })

        let s = status(scheduler, at: 1800)

        #expect(s.headline == .word("正在开会"))
        #expect(s.subtitle == "麦克风或摄像头正在使用")
        #expect(s.symbol == "mic")
        #expect(s.tint == .orange)
        #expect(s.ringFraction == 1)
        #expect(s.roundsText == "会议结束后先预告，再休息")
        #expect(s.secondTile == .pause(enabled: true, subtitle: "选择时长"))
    }

    @Test func onBreakCountsDownToEnd() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.breakNow(now: t0 + 100)

        let s = status(scheduler, at: 110)

        #expect(s.headline == .countdown("00:20"))
        #expect(s.subtitle == "后结束短休息")
        #expect(s.symbol == "cup.and.saucer")
        #expect(abs(s.ringFraction - 20.0 / 30) < 1e-9)
        #expect(s.roundsText == "第 1 / 4 轮")
        #expect(!s.breakNowEnabled)
        #expect(s.secondTile == .pause(enabled: false, subtitle: "休息中不可用"))
    }

    @Test func pausedUntilLaterToday() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.pause(until: t0 + 3600, now: t0)

        let s = status(scheduler)

        #expect(s.headline == .word("已暂停"))
        #expect(s.subtitle == "11:24 自动恢复")
        #expect(s.symbol == "pause")
        #expect(s.tint == .muted)
        #expect(s.ringFraction == 0)
        #expect(s.roundsText == "第 1 / 4 轮 · 恢复后从头计时")
        #expect(s.breakNowEnabled)
        #expect(s.secondTile == .resume)
    }

    @Test func pausedUntilTomorrowOrManually() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.pause(until: TestCalendar.date(2026, 10, 28, 0, 0), now: t0)
        #expect(status(scheduler).subtitle == "明天 00:00 自动恢复")

        scheduler.resume(now: t0)
        scheduler.pause(until: nil, now: t0)
        #expect(status(scheduler).subtitle == "直到手动恢复")
    }

    @Test func offHoursShowsNextStart() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)

        scheduler.workTimeChanged(.off(nextStart: TestCalendar.date(2026, 10, 27, 13, 0)), now: t0)
        #expect(status(scheduler).subtitle == "13:00 开始提醒")

        scheduler.workTimeChanged(.off(nextStart: TestCalendar.date(2026, 10, 28, 9, 0)), now: t0)
        #expect(status(scheduler).subtitle == "明天 09:00 开始提醒")

        scheduler.workTimeChanged(.off(nextStart: TestCalendar.date(2026, 11, 2, 9, 0)), now: t0)
        let s = status(scheduler)
        #expect(s.headline == .word("非工作时间"))
        #expect(s.subtitle == "周一 09:00 开始提醒")
        #expect(s.symbol == "moon")
        #expect(s.tint == .muted)
        #expect(s.dots == nil)
        #expect(s.breakNowEnabled)
        #expect(s.secondTile == .pause(enabled: false, subtitle: "非工作时间不可用"))

        scheduler.workTimeChanged(.off(nextStart: nil), now: t0)
        #expect(status(scheduler).subtitle == "未设置工作日")
    }

    @Test func awayShowsSinceWhen() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.userAway(since: t0 + 60, now: t0 + 360)

        let s = status(scheduler, at: 360)

        #expect(s.headline == .word("已离开"))
        #expect(s.subtitle == "10:25 起无操作")
        #expect(s.tint == .muted)
        #expect(s.roundsText == "第 1 / 4 轮 · 回来后从头计时")
        #expect(s.secondTile == .pause(enabled: false, subtitle: "离开时不可用"))
    }

    @Test func durationTexts() {
        #expect(PanelStatus.durationText(20) == "20 秒")
        #expect(PanelStatus.durationText(300) == "5 分钟")
        #expect(PanelStatus.durationText(90) == "1 分 30 秒")
    }

    /// 完成 n 次短休息之后（每轮 1830 秒）
    private func afterShortBreaks(_ n: Int) -> BreakScheduler {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        for i in 0..<n {
            let start = TimeInterval(i) * 1830
            scheduler.tick(now: t0 + start + 1770, isInMeeting: { false })
            scheduler.tick(now: t0 + start + 1800, isInMeeting: { false })
            scheduler.tick(now: t0 + start + 1830, isInMeeting: { false })
        }
        return scheduler
    }
}

enum TestCalendar {
    static let shanghai: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        shanghai.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
