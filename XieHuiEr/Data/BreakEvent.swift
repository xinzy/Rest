import Foundation
import SwiftData

/// 调度器产生的一条休息记录（plan.md §5.3）。枚举值以字符串存储，方便用 #Predicate 过滤。
@Model
final class BreakEvent {
    var at: Date
    /// short | long
    var kind: String
    /// completed | skipped | postponed | autoDeferred
    var type: String
    /// scheduled | manual
    var trigger: String

    init(at: Date, kind: String, type: String, trigger: String) {
        self.at = at
        self.kind = kind
        self.type = type
        self.trigger = trigger
    }
}

extension BreakKind {
    var storedName: String {
        switch self {
        case .short: return "short"
        case .long: return "long"
        }
    }

    /// 从数据库读回；无法识别的值返回 nil，报表查询时跳过
    init?(storedName: String) {
        switch storedName {
        case "short": self = .short
        case "long": self = .long
        default: return nil
        }
    }
}

extension BreakOutcome {
    var storedName: String {
        switch self {
        case .completed: return "completed"
        case .skipped: return "skipped"
        case .postponed: return "postponed"
        case .autoDeferred: return "autoDeferred"
        }
    }

    init?(storedName: String) {
        switch storedName {
        case "completed": self = .completed
        case "skipped": self = .skipped
        case "postponed": self = .postponed
        case "autoDeferred": self = .autoDeferred
        default: return nil
        }
    }
}

extension BreakTrigger {
    var storedName: String {
        switch self {
        case .scheduled: return "scheduled"
        case .manual: return "manual"
        }
    }

    init?(storedName: String) {
        switch storedName {
        case "scheduled": self = .scheduled
        case "manual": self = .manual
        default: return nil
        }
    }
}
