import Foundation

/// 计时状态机（plan.md §3）。纯逻辑，不读系统时钟：每个事件都带上当前时间，
/// 调用方读取 `state` 刷新界面，并保存方法返回的 `BreakRecord`。
///
/// 休息中、暂停、非工作时间、离开这四个条件分别保存，`state` 取优先级最高的那个。
/// 只要有一个条件成立，当前这一轮就作废；条件全部消失时，从那一刻开始新的一轮。
struct BreakScheduler {
    private(set) var settings: BreakSettings
    /// 距离上次长休息已经过去的轮数，始终不超过 longEvery − 1
    private(set) var roundsSinceLong = 0

    private var activeBreak: ActiveBreak?
    private var currentPause: Pause?
    private var workTime = WorkTime.on
    private var awaySince: Date?
    /// 正在计时的这一轮；有阻断条件时为 nil
    private var round: Round?
    /// 休息中修改的设置，等这次休息结束后生效
    private var pendingSettings: BreakSettings?

    fileprivate struct Pause {
        var until: Date?
    }

    fileprivate struct Round {
        var upcoming: UpcomingBreak
        var phase: Phase
    }

    fileprivate enum Phase: Equatable {
        case working
        case warning
        case deferred(recheckAt: Date)
    }

    init(settings: BreakSettings, now: Date) {
        self.settings = settings
        reconcile(now: now)
    }

    var state: BreakState {
        if let activeBreak { return .onBreak(activeBreak) }
        if let currentPause { return .paused(until: currentPause.until) }
        if case .off(let nextStart) = workTime { return .offHours(nextStart: nextStart) }
        if let awaySince { return .away(since: awaySince) }
        guard let round else { preconditionFailure("没有阻断条件时一定有一轮在计时") }
        switch round.phase {
        case .working: return .working(round.upcoming)
        case .warning: return .warning(round.upcoming)
        case .deferred(let recheckAt): return .deferred(round.upcoming, recheckAt: recheckAt)
        }
    }

    /// 下一次休息的类型
    var nextKind: BreakKind {
        settings.longBreakEnabled && roundsSinceLong >= settings.longEvery - 1 ? .long : .short
    }
}

// MARK: - 时钟

extension BreakScheduler {
    /// 主循环每秒调用一次，每次最多发生一次状态转移。
    /// 只有开启了开会推迟，并且到了预告时间、到点或复查时间时，才会调用 `isInMeeting`。
    @discardableResult
    mutating func tick(now: Date, isInMeeting: () -> Bool) -> [BreakRecord] {
        if let activeBreak {
            guard now >= activeBreak.endsAt else { return [] }
            // 按应结束的时间记录：电脑在休息中睡眠时，醒来才会走到这里
            return [endBreak(activeBreak, .completed, at: activeBreak.endsAt, now: now)]
        }
        if let currentPause {
            if let until = currentPause.until, now >= until { resume(now: now) }
            return []
        }
        guard var round else { return [] }

        switch round.phase {
        case .working:
            guard now >= round.upcoming.dueAt - settings.warningLead else { return [] }
            if meetingInProgress(isInMeeting) { return deferForMeeting(round, now: now) }
            warnOrStartBreak(round, now: now)
        case .warning:
            guard now >= round.upcoming.dueAt else { return [] }
            if meetingInProgress(isInMeeting) { return deferForMeeting(round, now: now) }
            startBreak(.scheduled, now: now)
        case .deferred(let recheckAt):
            guard now >= recheckAt else { return [] }
            if meetingInProgress(isInMeeting) {
                round.phase = .deferred(recheckAt: now + settings.meetingRecheckInterval)
                self.round = round
            } else {
                round.upcoming.dueAt = now + settings.warningLead
                warnOrStartBreak(round, now: now)
            }
        }
        return []
    }
}

// MARK: - 用户操作

extension BreakScheduler {
    /// 预告浮窗中的「推迟」
    @discardableResult
    mutating func postpone(now: Date) -> [BreakRecord] {
        guard var round, round.phase == .warning else { return [] }
        round.upcoming.dueAt = now + settings.postponeDuration
        round.phase = .working
        self.round = round
        return [BreakRecord(at: now, kind: nextKind, outcome: .postponed, trigger: .scheduled)]
    }

    /// 预告浮窗中的「立即开始」
    mutating func startNow(now: Date) {
        guard round?.phase == .warning else { return }
        startBreak(.scheduled, now: now)
    }

    /// 面板中的「立即休息」：类型和下一轮相同，并算作这一轮。休息结束后回到原来的状态（例如暂停）。
    mutating func breakNow(now: Date) {
        guard activeBreak == nil else { return }
        startBreak(.manual, now: now)
    }

    /// 遮罩上的「跳过休息」
    @discardableResult
    mutating func skip(now: Date) -> [BreakRecord] {
        guard let activeBreak else { return [] }
        // 倒计时已走完、主循环还没来得及结束这次休息
        if now >= activeBreak.endsAt {
            return [endBreak(activeBreak, .completed, at: activeBreak.endsAt, now: now)]
        }
        return [endBreak(activeBreak, .skipped, at: now, now: now)]
    }

    /// 暂停到 until，nil 表示直到手动恢复。只有工作中、预告和会议推迟时可以暂停。
    mutating func pause(until: Date?, now: Date) {
        guard round != nil else { return }
        currentPause = Pause(until: until)
        reconcile(now: now)
    }

    /// 恢复计时，开始新的一轮
    mutating func resume(now: Date) {
        guard currentPause != nil else { return }
        currentPause = nil
        reconcile(now: now)
    }

    /// 修改设置：休息中等这次休息结束后生效；其他状态下立即生效，当前这一轮从头计时，轮次计数保留
    mutating func updateSettings(_ newSettings: BreakSettings, now: Date) {
        guard newSettings != (pendingSettings ?? settings) else { return }
        if activeBreak != nil {
            pendingSettings = newSettings
            return
        }
        apply(newSettings)
        round = nil
        reconcile(now: now)
    }
}

// MARK: - 环境变化

extension BreakScheduler {
    /// 判定用户已离开。since 是最后一次输入、锁屏或睡眠的时间；已经离开时保留更早的时间。
    /// 正在进行的休息照常走完。
    mutating func userAway(since: Date, now: Date) {
        awaySince = min(awaySince ?? since, since)
        reconcile(now: now)
    }

    /// 用户回来了。离开时长不短于长休息时长时，长休息计数清零。
    mutating func userReturned(now: Date) {
        guard let awaySince else { return }
        if now.timeIntervalSince(awaySince) >= settings.longDuration {
            roundsSinceLong = 0
        }
        self.awaySince = nil
        reconcile(now: now)
    }

    /// 进入或离开工作时间。正在进行的休息照常走完。
    mutating func workTimeChanged(_ workTime: WorkTime, now: Date) {
        self.workTime = workTime
        reconcile(now: now)
    }
}

// MARK: - 内部

private extension BreakScheduler {
    /// 有阻断条件时作废当前这一轮；没有阻断条件并且不在计时时，从 now 开始新的一轮
    mutating func reconcile(now: Date) {
        let blocked = activeBreak != nil || currentPause != nil || workTime != .on || awaySince != nil
        if blocked {
            round = nil
        } else if round == nil {
            round = Round(upcoming: UpcomingBreak(dueAt: now + settings.shortInterval), phase: .working)
        }
    }

    func meetingInProgress(_ isInMeeting: () -> Bool) -> Bool {
        settings.meetingDeferEnabled && isInMeeting()
    }

    /// 开会时推迟这次休息；同一次休息只记一次自动推迟
    mutating func deferForMeeting(_ round: Round, now: Date) -> [BreakRecord] {
        var round = round
        let firstDeferral = !round.upcoming.autoDeferRecorded
        round.upcoming.autoDeferRecorded = true
        round.phase = .deferred(recheckAt: now + settings.meetingRecheckInterval)
        self.round = round
        guard firstDeferral else { return [] }
        return [BreakRecord(at: now, kind: nextKind, outcome: .autoDeferred, trigger: .scheduled)]
    }

    /// 有预告时进入预告，预告秒数为 0 时直接开始休息
    mutating func warnOrStartBreak(_ round: Round, now: Date) {
        guard settings.warningLead > 0 else {
            startBreak(.scheduled, now: now)
            return
        }
        var round = round
        round.phase = .warning
        self.round = round
    }

    mutating func startBreak(_ trigger: BreakTrigger, now: Date) {
        let kind = nextKind
        let duration = kind == .long ? settings.longDuration : settings.shortDuration
        activeBreak = ActiveBreak(kind: kind, trigger: trigger, startedAt: now, endsAt: now + duration)
        reconcile(now: now)
    }

    /// 结束休息并更新轮次，然后应用休息中修改的设置
    mutating func endBreak(_ active: ActiveBreak, _ outcome: BreakOutcome, at time: Date, now: Date) -> BreakRecord {
        switch active.kind {
        case .short:
            roundsSinceLong = min(roundsSinceLong + 1, settings.longEvery - 1)
        case .long where outcome == .completed:
            roundsSinceLong = 0
        case .long:
            break  // 跳过长休息时计数不变，下一轮仍是长休息
        }
        activeBreak = nil
        if let pendingSettings { apply(pendingSettings) }
        reconcile(now: now)
        return BreakRecord(at: time, kind: active.kind, outcome: outcome, trigger: active.trigger)
    }

    /// 计数截到新的 longEvery − 1 以内
    mutating func apply(_ newSettings: BreakSettings) {
        settings = newSettings
        pendingSettings = nil
        roundsSinceLong = min(roundsSinceLong, settings.longEvery - 1)
    }
}
