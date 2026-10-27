import Foundation

/// 离开判定（plan.md §3.2、§3.3）。纯逻辑：输入每秒钟的无操作时长、防息屏断言和锁屏/睡眠事件，
/// 输出「离开 / 回来」，由调用方转给 BreakScheduler。所有时间都由调用方传入。
struct PresenceTracker {
    enum Event: Equatable {
        /// 离开，since 是最后一次输入、锁屏或入睡的时间
        case away(since: Date)
        case returned(at: Date)
    }

    private(set) var awaySince: Date?
    private var isLocked = false
    private var isAsleep = false
    /// 最近一次回来的时间：解锁或唤醒后用它重新计算无操作时长
    private var lastReturnAt: Date?

    /// 每秒调用。无操作达到阈值且没有防息屏断言时离开；离开后恢复输入则回来。
    /// 防息屏断言为真时（例如在放视频）仍算在看屏幕。
    mutating func poll(
        now: Date,
        idleSeconds: TimeInterval,
        displaySleepPrevented: Bool,
        threshold: TimeInterval
    ) -> Event? {
        guard !isLocked, !isAsleep else { return nil }
        // 解锁或唤醒后从回来那一刻算起，避免把锁屏、睡眠前的无操作时长算进来
        let idle = lastReturnAt.map { min(idleSeconds, now.timeIntervalSince($0)) } ?? idleSeconds
        if awaySince == nil {
            guard idle >= threshold, !displaySleepPrevented else { return nil }
            let since = now - idle
            awaySince = since
            return .away(since: since)
        }
        guard idle < threshold else { return nil }
        return returnBack(now: now)
    }

    /// 锁屏视为离开；已经离开时保留更早的时间
    mutating func locked(at time: Date) -> Event? {
        isLocked = true
        return enterAway(since: time)
    }

    mutating func unlocked(at time: Date) -> Event? {
        isLocked = false
        return leaveAway(now: time)
    }

    /// 睡眠视为离开
    mutating func slept(at time: Date) -> Event? {
        isAsleep = true
        return enterAway(since: time)
    }

    /// 唤醒时如果屏幕仍然锁着，要等解锁才算回来
    mutating func woke(at time: Date) -> Event? {
        isAsleep = false
        return leaveAway(now: time)
    }

    /// 开始离开：新的时间更早时更新并返回事件；已经离开且新时间更晚则忽略
    private mutating func enterAway(since: Date) -> Event? {
        if let awaySince, awaySince <= since { return nil }
        awaySince = since
        return .away(since: since)
    }

    private mutating func leaveAway(now: Date) -> Event? {
        guard !isLocked, !isAsleep else { return nil }
        lastReturnAt = now
        guard awaySince != nil else { return nil }
        return returnBack(now: now)
    }

    private mutating func returnBack(now: Date) -> Event {
        awaySince = nil
        lastReturnAt = now
        return .returned(at: now)
    }
}
