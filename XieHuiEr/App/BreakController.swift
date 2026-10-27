import Foundation
import Observation
import os

/// 主循环：每秒驱动一次调度器，并把用户操作转给调度器。界面通过 Observation 读取 `scheduler` 和 `now`。
@MainActor
@Observable
final class BreakController {
    private(set) var scheduler: BreakScheduler
    /// 最近一次刷新的时间，界面按它计算倒计时
    private(set) var now: Date

    /// 每次刷新后调用，菜单栏图标据此重绘
    @ObservationIgnored var onChange: (() -> Void)?
    /// 休息开始时调用（到点、预告中立即开始、面板立即休息）
    @ObservationIgnored var onBreakStarted: ((ActiveBreak) -> Void)?
    /// 休息结束（完成或跳过）时调用
    @ObservationIgnored var onBreakEnded: ((BreakRecord) -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let logger = Logger(subsystem: "com.shaozeng.xiehuier", category: "BreakController")

    init(settings: BreakSettings) {
        let now = Date()
        self.now = now
        scheduler = BreakScheduler(settings: settings, now: now)
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        // .common：面板中的暂停菜单展开时也要继续计时
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func breakNow() {
        update { scheduler, now in
            scheduler.breakNow(now: now)
            return []
        }
    }

    func skipBreak() {
        update { scheduler, now in
            scheduler.skip(now: now)
        }
    }

    func pause(_ option: PauseOption) {
        update { scheduler, now in
            scheduler.pause(until: option.until(now: now, calendar: .current), now: now)
            return []
        }
    }

    func resume() {
        update { scheduler, now in
            scheduler.resume(now: now)
            return []
        }
    }

    private func tick() {
        // 会议检测在 S6 接入
        update { $0.tick(now: $1, isInMeeting: { false }) }
    }

    private func update(_ change: (inout BreakScheduler, Date) -> [BreakRecord]) {
        now = Date()
        let wasOnBreak = scheduler.state.isOnBreak
        let records = change(&scheduler, now)
        // 记录在 S8 写入数据库，目前只写日志
        for record in records {
            logger.info("休息记录：\(String(describing: record.kind), privacy: .public) \(String(describing: record.outcome), privacy: .public) \(String(describing: record.trigger), privacy: .public)")
        }
        if case .onBreak(let active) = scheduler.state, !wasOnBreak {
            onBreakStarted?(active)
        }
        for record in records where record.outcome == .completed || record.outcome == .skipped {
            onBreakEnded?(record)
        }
        onChange?()
    }
}
