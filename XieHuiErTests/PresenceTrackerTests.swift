import Foundation
import Testing
@testable import XieHuiEr

/// 离开判定（plan.md §3.2、§3.3）
struct PresenceTrackerTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let threshold: TimeInterval = 300

    private func poll(
        _ tracker: inout PresenceTracker,
        now: Date,
        idle: TimeInterval,
        prevented: Bool = false
    ) -> PresenceTracker.Event? {
        tracker.poll(now: now, idleSeconds: idle, displaySleepPrevented: prevented, threshold: threshold)
    }

    @Test func awayAfterThreshold() {
        var tracker = PresenceTracker()

        #expect(poll(&tracker, now: t0, idle: 299) == nil)
        #expect(poll(&tracker, now: t0 + 300, idle: 300) == .away(since: t0))
    }

    @Test func displaySleepAssertionKeepsUserPresent() {
        var tracker = PresenceTracker()

        #expect(poll(&tracker, now: t0, idle: 600, prevented: true) == nil)
        #expect(tracker.awaySince == nil)
    }

    @Test func inputBringsUserBack() {
        var tracker = PresenceTracker()
        _ = poll(&tracker, now: t0, idle: 300)

        #expect(poll(&tracker, now: t0 + 1, idle: 0) == .returned(at: t0 + 1))
        #expect(tracker.awaySince == nil)
    }

    @Test func lockAndUnlock() {
        var tracker = PresenceTracker()

        #expect(tracker.locked(at: t0) == .away(since: t0))
        // 锁屏期间轮询不会判定回来
        #expect(poll(&tracker, now: t0 + 600, idle: 0) == nil)
        #expect(tracker.unlocked(at: t0 + 600) == .returned(at: t0 + 600))
    }

    @Test func wakeWhileStillLockedStaysAway() {
        var tracker = PresenceTracker()
        _ = tracker.locked(at: t0)
        _ = tracker.slept(at: t0 + 100)

        #expect(tracker.woke(at: t0 + 400) == nil)
        #expect(tracker.awaySince != nil)
        #expect(tracker.unlocked(at: t0 + 500) == .returned(at: t0 + 500))
    }

    @Test func sleepAndWake() {
        var tracker = PresenceTracker()

        #expect(tracker.slept(at: t0) == .away(since: t0))
        #expect(tracker.woke(at: t0 + 3600) == .returned(at: t0 + 3600))
    }

    @Test func earlierAwayTimeIsKept() {
        var tracker = PresenceTracker()
        _ = poll(&tracker, now: t0, idle: 300)

        #expect(tracker.locked(at: t0 + 100) == nil)
        #expect(tracker.awaySince == t0 - 300)
    }

    @Test func idleIsCountedFromReturnTime() {
        var tracker = PresenceTracker()
        _ = tracker.locked(at: t0)
        _ = tracker.unlocked(at: t0 + 600)

        // 解锁前已经很久没输入，解锁后不会立刻再次离开
        #expect(poll(&tracker, now: t0 + 601, idle: 900) == nil)
        // 从解锁那一刻起满阈值才再次离开
        #expect(poll(&tracker, now: t0 + 600 + threshold, idle: 1200) == .away(since: t0 + 600))
    }
}
