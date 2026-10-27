import Foundation

enum BreakKind: Sendable {
    case short, long
}

/// 休息是怎么开始的
enum BreakTrigger: Sendable {
    /// 按计划到点，包括在预告浮窗中点「立即开始」
    case scheduled
    /// 在面板中点「立即休息」
    case manual
}

enum BreakOutcome: Sendable {
    case completed, skipped, postponed, autoDeferred
}

/// 调度器产生的一条休息记录，由调用方保存，用于报表
struct BreakRecord: Equatable, Sendable {
    var at: Date
    var kind: BreakKind
    var outcome: BreakOutcome
    var trigger: BreakTrigger
}

/// 即将到来的那次休息。它的类型由调度器的 `nextKind` 决定。
struct UpcomingBreak: Equatable, Sendable {
    var dueAt: Date
    /// 这次休息是否已经记过一次开会自动推迟
    var autoDeferRecorded = false
}

struct ActiveBreak: Equatable, Sendable {
    var kind: BreakKind
    var trigger: BreakTrigger
    var startedAt: Date
    var endsAt: Date
}

/// 调度器对外的状态，按 plan.md §3.1 的优先级从高到低排列
enum BreakState: Equatable, Sendable {
    case onBreak(ActiveBreak)
    /// until 为 nil 表示直到手动恢复
    case paused(until: Date?)
    /// nextStart 为 nil 表示没有设置任何工作日
    case offHours(nextStart: Date?)
    case away(since: Date)
    case deferred(UpcomingBreak, recheckAt: Date)
    case warning(UpcomingBreak)
    case working(UpcomingBreak)

    var isOnBreak: Bool {
        if case .onBreak = self { return true }
        return false
    }
}

/// 当前是否在工作时间内
enum WorkTime: Equatable, Sendable {
    case on
    case off(nextStart: Date?)
}
