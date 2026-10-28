import Foundation
import os
import SwiftData

/// 一天的喝水杯数，供报表和测试使用
struct WaterDayCount: Equatable, Sendable {
    /// 本地 0 点
    var day: Date
    var count: Int
}

/// SwiftData 的读写入口（plan.md §5.3）。所有操作都在主线程进行。
@MainActor
final class DataStore {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.shaozeng.xiehuier", category: "DataStore")

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    /// 记录存本机；打不开数据库时退回内存库，不影响休息计时
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(url: defaultStoreURL())
        }
        do {
            return try ModelContainer(for: WaterRecord.self, BreakEvent.self, configurations: configuration)
        } catch {
            Logger(subsystem: "com.shaozeng.xiehuier", category: "DataStore")
                .error("打开数据库失败，改用内存数据库：\(String(describing: error), privacy: .public)")
        }
        let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
        // 内存库也失败说明 SwiftData 不可用，没有可降级的方案
        return try! ModelContainer(for: WaterRecord.self, BreakEvent.self, configurations: fallback)
    }

    /// ~/Library/Application Support/XieHuiEr/Records.store，不用 SwiftData 默认的公共 default.store
    private static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("XieHuiEr", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("Records.store")
    }

    // MARK: - 喝水

    @discardableResult
    func addWater(at time: Date) -> WaterRecord {
        let record = WaterRecord(drankAt: time)
        context.insert(record)
        save()
        return record
    }

    func delete(_ record: WaterRecord) {
        context.delete(record)
        save()
    }

    func lastDrinkAt() -> Date? {
        var descriptor = FetchDescriptor<WaterRecord>(sortBy: [SortDescriptor(\.drankAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.drankAt
    }

    /// [start, end) 内的喝水条数
    func waterCount(from start: Date, to end: Date) -> Int {
        let predicate = #Predicate<WaterRecord> { $0.drankAt >= start && $0.drankAt < end }
        return (try? context.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0
    }

    /// 近 lastDays 天每天（本地 0 点起）的杯数，从早到晚排列
    func waterCounts(lastDays: Int, now: Date, calendar: Calendar) -> [WaterDayCount] {
        let today = calendar.startOfDay(for: now)
        guard lastDays > 0,
              let first = calendar.date(byAdding: .day, value: -(lastDays - 1), to: today) else {
            return []
        }
        let predicate = #Predicate<WaterRecord> { $0.drankAt >= first }
        let records = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        var counts: [Date: Int] = [:]
        for record in records {
            counts[calendar.startOfDay(for: record.drankAt), default: 0] += 1
        }
        return (0..<lastDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            return WaterDayCount(day: day, count: counts[day] ?? 0)
        }
    }

    // MARK: - 休息

    func addBreakEvent(_ record: BreakRecord) {
        let event = BreakEvent(
            at: record.at,
            kind: record.kind.storedName,
            type: record.outcome.storedName,
            trigger: record.trigger.storedName
        )
        context.insert(event)
        save()
    }

    func breakEvents() -> [BreakEvent] {
        (try? context.fetch(FetchDescriptor<BreakEvent>(sortBy: [SortDescriptor(\.at)]))) ?? []
    }

    private func save() {
        do {
            try context.save()
        } catch {
            logger.error("保存失败：\(String(describing: error), privacy: .public)")
        }
    }
}
