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
    /// 产生一条休息记录时调用（完成、跳过、推迟、自动推迟），由 AppDelegate 接到 DataStore
    @ObservationIgnored var onBreakRecorded: ((BreakRecord) -> Void)?
    /// 麦克风或摄像头是否正在使用，由 AppDelegate 接到 MeetingDetector
    @ObservationIgnored var isInMeeting: () -> Bool = { false }
    /// 当前是否在工作时间内，由 AppDelegate 按设置计算；DEBUG 可替换
    @ObservationIgnored var currentWorkTime: (Date) -> WorkTime = { _ in .on }
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

    /// 预告浮窗中的「推迟」
    func postpone() {
        update { scheduler, now in
            scheduler.postpone(now: now)
        }
    }

    /// 预告浮窗中的「立即开始」
    func startNow() {
        update { scheduler, now in
            scheduler.startNow(now: now)
            return []
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

    /// 判定用户已离开。since 是最后一次输入、锁屏或睡眠的时间
    func userAway(since: Date) {
        update { scheduler, now in
            scheduler.userAway(since: since, now: now)
            return []
        }
    }

    /// 用户回来了；离开不短于长休息时长时，长休息计数清零
    func userReturned() {
        update { scheduler, now in
            scheduler.userReturned(now: now)
            return []
        }
    }

    private func tick() {
        let isInMeeting = self.isInMeeting
        let now = Date()
        // 在工作时间判定里读调度器会和下面 update 的 inout 访问冲突，先取出来
        let workTime = currentWorkTime(now)
        update(at: now) { scheduler, now in
            // 工作时间离开后不再触发新的休息；进入工作时间时如果用户已离开，离开判定会继续挡住这一轮
            scheduler.workTimeChanged(workTime, now: now)
            return scheduler.tick(now: now, isInMeeting: isInMeeting)
        }
    }

    private func update(at time: Date = Date(), _ change: (inout BreakScheduler, Date) -> [BreakRecord]) {
        now = time
        let wasOnBreak = scheduler.state.isOnBreak
        let records = change(&scheduler, now)
        // 记录写入数据库（S8）
        for record in records {
            logger.info("休息记录：\(String(describing: record.kind), privacy: .public) \(String(describing: record.outcome), privacy: .public) \(String(describing: record.trigger), privacy: .public)")
            onBreakRecorded?(record)
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
