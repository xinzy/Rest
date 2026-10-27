import Foundation
import Testing
@testable import XieHuiEr

/// 计时状态机（plan.md §3）。默认设置：每 30 分钟休息 30 秒，每 4 轮一次 5 分钟的长休息，
/// 提前 30 秒预告，推迟 5 分钟，开会时每 60 秒复查一次。时间都写成距 t0 的秒数。
struct BreakSchedulerTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    // MARK: 正常流程

    @Test func countsDownWarnsThenBreaksAndStartsNextRound() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        #expect(scheduler.state == working(due: 1800))

        #expect(scheduler.tick(at(1769)).isEmpty)
        #expect(scheduler.state == working(due: 1800))

        scheduler.tick(at(1770))
        #expect(scheduler.state == warning(due: 1800))
        scheduler.tick(at(1799))
        #expect(scheduler.state == warning(due: 1800))

        scheduler.tick(at(1800))
        #expect(scheduler.state == onBreak(from: 1800, to: 1830))

        #expect(scheduler.tick(at(1829)).isEmpty)
        #expect(scheduler.tick(at(1830)) == [record(.completed, at: 1830)])
        #expect(scheduler.roundsSinceLong == 1)
        #expect(scheduler.state == working(due: 3630))
    }

    @Test func withoutWarningGoesStraightToBreak() {
        var settings = BreakSettings()
        settings.warningLead = 0
        var scheduler = BreakScheduler(settings: settings, now: t0)

        scheduler.tick(at(1799))
        #expect(scheduler.state == working(due: 1800))
        scheduler.tick(at(1800))
        #expect(scheduler.state == onBreak(from: 1800, to: 1830))
    }

    @Test func postponeMovesDueTimeAndIsRecorded() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        #expect(scheduler.postpone(now: at(100)).isEmpty, "只有预告时可以推迟")
        #expect(scheduler.state == working(due: 1800))

        scheduler.tick(at(1770))
        #expect(scheduler.postpone(now: at(1775)) == [record(.postponed, at: 1775)])
        #expect(scheduler.state == working(due: 2075))

        scheduler.tick(at(2044))
        #expect(scheduler.state == working(due: 2075))
        scheduler.tick(at(2045))
        #expect(scheduler.state == warning(due: 2075))
    }

    @Test func startNowFromWarning() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.startNow(now: at(100))
        #expect(scheduler.state == working(due: 1800), "只有预告时可以立即开始")

        scheduler.tick(at(1770))
        scheduler.startNow(now: at(1780))
        #expect(scheduler.state == onBreak(from: 1780, to: 1810))
    }

    // MARK: 轮次

    @Test func skippingShortBreakCountsAsRound() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(at(1770))
        scheduler.tick(at(1800))

        #expect(scheduler.skip(now: at(1805)) == [record(.skipped, at: 1805)])
        #expect(scheduler.roundsSinceLong == 1)
        #expect(scheduler.state == working(due: 3605))
    }

    /// 倒计时已经走完、主循环还没来得及结束时点了跳过，按完成处理
    @Test func skipAfterEndTimeCountsAsCompleted() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        for _ in 0..<3 { completeScheduledBreak(&scheduler) }
        scheduler.tick(at(7260))
        scheduler.tick(at(7290))

        #expect(scheduler.skip(now: at(7590.5)) == [record(.completed, at: 7590, kind: .long)])
        #expect(scheduler.roundsSinceLong == 0)
    }

    @Test func everyFourthRoundIsLong() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        var kinds: [BreakKind?] = []
        for _ in 0..<8 { kinds.append(completeScheduledBreak(&scheduler)) }

        #expect(kinds == [.short, .short, .short, .long, .short, .short, .short, .long])
        #expect(scheduler.roundsSinceLong == 0)
    }

    @Test func skippedLongBreakComesBackNextRound() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        for _ in 0..<3 { completeScheduledBreak(&scheduler) }
        // 3 轮之后 t = 5490，长休息在 7290 到点
        scheduler.tick(at(7260))
        scheduler.tick(at(7290))
        #expect(scheduler.state == onBreak(.long, from: 7290, to: 7590))

        #expect(scheduler.skip(now: at(7300)) == [record(.skipped, at: 7300, kind: .long)])
        #expect(scheduler.roundsSinceLong == 3)
        #expect(completeScheduledBreak(&scheduler) == .long)
        #expect(scheduler.roundsSinceLong == 0)
    }

    @Test func withLongBreaksOffCountStopsAtLastRound() {
        var settings = BreakSettings()
        settings.longBreakEnabled = false
        var scheduler = BreakScheduler(settings: settings, now: t0)
        var kinds: [BreakKind?] = []
        for _ in 0..<5 { kinds.append(completeScheduledBreak(&scheduler)) }

        #expect(kinds == [BreakKind?](repeating: .short, count: 5))
        #expect(scheduler.roundsSinceLong == 3)

        settings.longBreakEnabled = true
        scheduler.updateSettings(settings, now: at(5 * 1830))
        #expect(scheduler.nextKind == .long)
    }

    @Test func loweringLongEveryClampsCount() {
        var settings = BreakSettings()
        settings.longEvery = 10
        var scheduler = BreakScheduler(settings: settings, now: t0)
        for _ in 0..<5 { completeScheduledBreak(&scheduler) }
        #expect(scheduler.roundsSinceLong == 5)

        settings.longEvery = 4
        scheduler.updateSettings(settings, now: at(5 * 1830))
        #expect(scheduler.roundsSinceLong == 3)
        #expect(scheduler.nextKind == .long)
    }

    @Test func breakNowTakesNextKindAndCountsAsRound() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.breakNow(now: at(100))
        #expect(scheduler.state == onBreak(.short, .manual, from: 100, to: 130))

        scheduler.breakNow(now: at(110))
        #expect(scheduler.state == onBreak(.short, .manual, from: 100, to: 130), "休息中不能再开始一次")

        #expect(scheduler.tick(at(130)) == [record(.completed, at: 130, trigger: .manual)])
        #expect(scheduler.roundsSinceLong == 1)
        #expect(scheduler.state == working(due: 1930))

        for _ in 0..<2 { completeScheduledBreak(&scheduler) }
        // t = 130 + 2 × 1830 = 3790，下一轮是长休息
        scheduler.breakNow(now: at(3800))
        #expect(scheduler.state == onBreak(.long, .manual, from: 3800, to: 4100))
    }

    // MARK: 暂停

    @Test func pauseUntilTimeThenNewRoundKeepingCount() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        completeScheduledBreak(&scheduler)
        scheduler.pause(until: at(2400), now: at(1900))
        #expect(scheduler.state == .paused(until: at(2400)))

        scheduler.tick(at(2399))
        #expect(scheduler.state == .paused(until: at(2400)))
        scheduler.tick(at(2400))
        #expect(scheduler.state == working(due: 4200))
        #expect(scheduler.roundsSinceLong == 1)
    }

    @Test func pauseUntilResumedByHand() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.pause(until: nil, now: at(100))
        scheduler.tick(at(100_000))
        #expect(scheduler.state == .paused(until: nil))

        scheduler.resume(now: at(100_000))
        #expect(scheduler.state == working(due: 101_800))
    }

    @Test func pauseDuringWarningOrMeetingDeferral() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(at(1770))
        scheduler.pause(until: nil, now: at(1775))
        #expect(scheduler.state == .paused(until: nil))

        scheduler.resume(now: at(2000))
        scheduler.tick(now: at(3770), isInMeeting: { true })
        #expect(scheduler.state == deferred(due: 3800, recheck: 3830))
        scheduler.pause(until: nil, now: at(3775))
        #expect(scheduler.state == .paused(until: nil))
    }

    @Test func cannotPauseOnBreakOrOffHours() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.breakNow(now: at(100))
        scheduler.pause(until: nil, now: at(110))
        scheduler.tick(at(130))
        #expect(scheduler.state == working(due: 1930))

        scheduler.workTimeChanged(.off(nextStart: nil), now: at(200))
        scheduler.pause(until: nil, now: at(210))
        scheduler.workTimeChanged(.on, now: at(300))
        #expect(scheduler.state == working(due: 2100))
    }

    @Test func breakNowWhilePausedReturnsToPause() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.pause(until: nil, now: at(10))
        scheduler.breakNow(now: at(20))
        #expect(scheduler.state == onBreak(.short, .manual, from: 20, to: 50))

        scheduler.tick(at(50))
        #expect(scheduler.state == .paused(until: nil))
        #expect(scheduler.roundsSinceLong == 1)
    }

    // MARK: 修改设置

    @Test func changingSettingsRestartsRoundAndKeepsCount() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        completeScheduledBreak(&scheduler)
        var settings = BreakSettings()
        settings.shortInterval = 1200

        scheduler.updateSettings(settings, now: at(2000))
        #expect(scheduler.state == working(due: 3200))
        #expect(scheduler.roundsSinceLong == 1)

        scheduler.updateSettings(settings, now: at(2500))
        #expect(scheduler.state == working(due: 3200), "设置没有变化时不重新计时")
    }

    @Test func settingsChangedDuringBreakApplyAfterIt() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.breakNow(now: at(100))
        var settings = BreakSettings()
        settings.shortInterval = 600
        settings.shortDuration = 20

        scheduler.updateSettings(settings, now: at(110))
        #expect(scheduler.state == onBreak(.short, .manual, from: 100, to: 130))
        #expect(scheduler.settings == BreakSettings())

        scheduler.tick(at(130))
        #expect(scheduler.settings == settings)
        #expect(scheduler.state == working(due: 730))
    }

    // MARK: 开会

    @Test func meetingDefersBreakAndRechecksUntilItEnds() {
        let meeting = MeetingProbe(inMeeting: true)
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)

        scheduler.tick(now: at(1769), isInMeeting: meeting.check)
        #expect(meeting.queries == 0, "没到预告时间不检测")

        #expect(scheduler.tick(now: at(1770), isInMeeting: meeting.check) == [record(.autoDeferred, at: 1770)])
        #expect(scheduler.state == deferred(due: 1800, recheck: 1830))

        scheduler.tick(now: at(1829), isInMeeting: meeting.check)
        #expect(meeting.queries == 1)

        #expect(scheduler.tick(now: at(1830), isInMeeting: meeting.check).isEmpty)
        #expect(scheduler.state == deferred(due: 1800, recheck: 1890))

        meeting.inMeeting = false
        scheduler.tick(now: at(1890), isInMeeting: meeting.check)
        #expect(scheduler.state == .warning(UpcomingBreak(dueAt: at(1920), autoDeferRecorded: true)))

        meeting.inMeeting = true
        #expect(scheduler.tick(now: at(1920), isInMeeting: meeting.check).isEmpty, "同一次休息只记一次自动推迟")
        #expect(scheduler.state == deferred(due: 1920, recheck: 1980))
    }

    @Test func autoDeferRecordedOnceEvenAfterPostpone() {
        let meeting = MeetingProbe(inMeeting: true)
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(now: at(1770), isInMeeting: meeting.check)
        meeting.inMeeting = false
        scheduler.tick(now: at(1830), isInMeeting: meeting.check)
        scheduler.postpone(now: at(1840))
        #expect(scheduler.state == .working(UpcomingBreak(dueAt: at(2140), autoDeferRecorded: true)))

        meeting.inMeeting = true
        #expect(scheduler.tick(now: at(2110), isInMeeting: meeting.check).isEmpty)
        #expect(scheduler.state == deferred(due: 2140, recheck: 2170))
    }

    @Test func breakNowOrAwayDuringMeetingDeferral() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(now: at(1770), isInMeeting: { true })
        scheduler.breakNow(now: at(1780))
        #expect(scheduler.state == onBreak(.short, .manual, from: 1780, to: 1810))
        scheduler.tick(at(1810))
        #expect(scheduler.state == working(due: 3610), "休息后开始新的一轮，不再推迟")

        scheduler.tick(now: at(3580), isInMeeting: { true })
        scheduler.userAway(since: at(3300), now: at(3600))
        #expect(scheduler.state == .away(since: at(3300)))
    }

    @Test func meetingStartingDuringWarningDefersAtDueTime() {
        let meeting = MeetingProbe(inMeeting: false)
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(now: at(1770), isInMeeting: meeting.check)
        #expect(scheduler.state == warning(due: 1800))

        meeting.inMeeting = true
        #expect(scheduler.tick(now: at(1800), isInMeeting: meeting.check) == [record(.autoDeferred, at: 1800)])
        #expect(scheduler.state == deferred(due: 1800, recheck: 1860))
    }

    @Test func meetingEndingWithoutWarningStartsBreak() {
        var settings = BreakSettings()
        settings.warningLead = 0
        let meeting = MeetingProbe(inMeeting: true)
        var scheduler = BreakScheduler(settings: settings, now: t0)
        scheduler.tick(now: at(1800), isInMeeting: meeting.check)
        #expect(scheduler.state == deferred(due: 1800, recheck: 1860))

        meeting.inMeeting = false
        scheduler.tick(now: at(1860), isInMeeting: meeting.check)
        #expect(scheduler.state == onBreak(from: 1860, to: 1890))
    }

    @Test func meetingNotCheckedWhenDeferralOff() {
        var settings = BreakSettings()
        settings.meetingDeferEnabled = false
        let meeting = MeetingProbe(inMeeting: true)
        var scheduler = BreakScheduler(settings: settings, now: t0)

        scheduler.tick(now: at(1770), isInMeeting: meeting.check)
        scheduler.tick(now: at(1800), isInMeeting: meeting.check)
        #expect(scheduler.state == onBreak(from: 1800, to: 1830))
        #expect(meeting.queries == 0)
    }

    // MARK: 离开

    @Test func shortAbsenceKeepsCountLongOneResetsIt() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        completeScheduledBreak(&scheduler)

        scheduler.userAway(since: at(2000), now: at(2000))
        #expect(scheduler.state == .away(since: at(2000)))
        scheduler.userReturned(now: at(2299))
        #expect(scheduler.roundsSinceLong == 1)
        #expect(scheduler.state == working(due: 4099))

        scheduler.userAway(since: at(3000), now: at(3000))
        scheduler.userReturned(now: at(3300))
        #expect(scheduler.roundsSinceLong == 0, "离开时长达到长休息时长")
        #expect(scheduler.state == working(due: 5100))
    }

    @Test func noBreakWhileAwayAndEarliestAwayTimeKept() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(at(1770))
        scheduler.userAway(since: at(1480), now: at(1780))
        #expect(scheduler.state == .away(since: at(1480)))

        scheduler.userAway(since: at(1790), now: at(1790))
        #expect(scheduler.tick(at(5000)).isEmpty)
        #expect(scheduler.state == .away(since: at(1480)))
    }

    @Test func breakRunsOutWhileAwayThenStaysAway() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.breakNow(now: at(100))
        scheduler.userAway(since: at(110), now: at(110))
        #expect(scheduler.state == onBreak(.short, .manual, from: 100, to: 130))

        #expect(scheduler.tick(at(130)) == [record(.completed, at: 130, trigger: .manual)])
        #expect(scheduler.state == .away(since: at(110)))

        scheduler.userReturned(now: at(200))
        #expect(scheduler.state == working(due: 2000))
        #expect(scheduler.roundsSinceLong == 1)
    }

    // MARK: 工作时间

    @Test func offHoursStopsRemindersUntilWorkTimeStarts() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(at(1770))
        scheduler.workTimeChanged(.off(nextStart: at(50_000)), now: at(1780))
        #expect(scheduler.state == .offHours(nextStart: at(50_000)))

        #expect(scheduler.tick(at(1800)).isEmpty)
        #expect(scheduler.state == .offHours(nextStart: at(50_000)))

        scheduler.workTimeChanged(.on, now: at(50_000))
        #expect(scheduler.state == working(due: 51_800))
    }

    @Test func breakInProgressFinishesBeforeOffHours() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.tick(at(1770))
        scheduler.tick(at(1800))
        scheduler.workTimeChanged(.off(nextStart: nil), now: at(1810))
        #expect(scheduler.state == onBreak(from: 1800, to: 1830))

        scheduler.tick(at(1830))
        #expect(scheduler.state == .offHours(nextStart: nil))
    }

    @Test func breakNowDuringOffHoursCountsAndReturnsToOffHours() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.workTimeChanged(.off(nextStart: nil), now: at(100))
        scheduler.breakNow(now: at(200))
        #expect(scheduler.state == onBreak(.short, .manual, from: 200, to: 230))

        scheduler.tick(at(230))
        #expect(scheduler.state == .offHours(nextStart: nil))
        #expect(scheduler.roundsSinceLong == 1)
    }

    @Test func workTimeStartingWhileAwayWaitsForReturn() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.workTimeChanged(.off(nextStart: at(10_000)), now: at(100))
        scheduler.userAway(since: at(200), now: at(500))
        #expect(scheduler.state == .offHours(nextStart: at(10_000)))

        scheduler.workTimeChanged(.on, now: at(10_000))
        #expect(scheduler.state == .away(since: at(200)))

        scheduler.userReturned(now: at(10_500))
        #expect(scheduler.state == working(due: 12_300))
    }

    @Test func pauseOutranksOffHours() {
        var scheduler = BreakScheduler(settings: BreakSettings(), now: t0)
        scheduler.pause(until: at(1000), now: at(100))
        scheduler.workTimeChanged(.off(nextStart: at(5000)), now: at(500))
        #expect(scheduler.state == .paused(until: at(1000)))

        scheduler.tick(at(1000))
        #expect(scheduler.state == .offHours(nextStart: at(5000)))
    }

    // MARK: 测试辅助

    private func at(_ seconds: TimeInterval) -> Date { t0 + seconds }

    private func working(due: TimeInterval) -> BreakState {
        .working(UpcomingBreak(dueAt: at(due)))
    }

    private func warning(due: TimeInterval) -> BreakState {
        .warning(UpcomingBreak(dueAt: at(due)))
    }

    /// 开会推迟（已记过一次 autoDeferred）
    private func deferred(due: TimeInterval, recheck: TimeInterval) -> BreakState {
        .deferred(UpcomingBreak(dueAt: at(due), autoDeferRecorded: true), recheckAt: at(recheck))
    }

    private func onBreak(
        _ kind: BreakKind = .short, _ trigger: BreakTrigger = .scheduled,
        from start: TimeInterval, to end: TimeInterval
    ) -> BreakState {
        .onBreak(ActiveBreak(kind: kind, trigger: trigger, startedAt: at(start), endsAt: at(end)))
    }

    private func record(
        _ outcome: BreakOutcome, at time: TimeInterval,
        kind: BreakKind = .short, trigger: BreakTrigger = .scheduled
    ) -> BreakRecord {
        BreakRecord(at: at(time), kind: kind, outcome: outcome, trigger: trigger)
    }

    /// 按计划走完下一次休息（预告 → 休息 → 倒计时结束），返回这次休息的类型
    @discardableResult
    private func completeScheduledBreak(_ scheduler: inout BreakScheduler) -> BreakKind? {
        guard case .working(let upcoming) = scheduler.state else { return nil }
        scheduler.tick(upcoming.dueAt - scheduler.settings.warningLead)
        scheduler.tick(upcoming.dueAt)
        guard case .onBreak(let active) = scheduler.state else { return nil }
        scheduler.tick(active.endsAt)
        return active.kind
    }
}

/// 可控的会议状态，并统计被查询的次数
private final class MeetingProbe {
    var inMeeting: Bool
    private(set) var queries = 0

    init(inMeeting: Bool) { self.inMeeting = inMeeting }

    func check() -> Bool {
        queries += 1
        return inMeeting
    }
}

private extension BreakScheduler {
    /// 不在开会时的时钟推进
    @discardableResult
    mutating func tick(_ now: Date) -> [BreakRecord] {
        tick(now: now, isInMeeting: { false })
    }
}
