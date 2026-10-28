import Foundation
import SwiftData

/// 一条喝水记录（plan.md §5.3）。当天的杯数 = 本地 0 点起的记录条数。
@Model
final class WaterRecord {
    var drankAt: Date

    init(drankAt: Date) {
        self.drankAt = drankAt
    }
}
