import Foundation
import os

/// 把无操作、锁屏、睡眠事件接到控制器上（plan.md §3.3），每秒检查一次。
@MainActor
final class PresenceMonitor {
    private let controller: BreakController
    private let session = SessionMonitor()
    private var tracker = PresenceTracker()
    private var timer: Timer?
    private let logger = Logger(subsystem: "com.shaozeng.xiehuier", category: "PresenceMonitor")

    init(controller: BreakController) {
        self.controller = controller
        session.onLock = { [weak self] time in
            guard let self else { return }
            apply(tracker.locked(at: time))
        }
        session.onUnlock = { [weak self] time in
            guard let self else { return }
            apply(tracker.unlocked(at: time))
        }
        session.onSleep = { [weak self] time in
            guard let self else { return }
            apply(tracker.slept(at: time))
        }
        session.onWake = { [weak self] time in
            guard let self else { return }
            apply(tracker.woke(at: time))
        }
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let now = Date()
        let threshold = controller.scheduler.settings.awayThreshold
        let idle = IdleMonitor.secondsSinceLastInput()
        // 只有可能判定为离开时才去查防息屏断言
        let prevented = idle >= threshold && DisplaySleepAssertions.isPrevented()
        apply(tracker.poll(now: now, idleSeconds: idle, displaySleepPrevented: prevented, threshold: threshold))
    }

    private func apply(_ event: PresenceTracker.Event?) {
        guard let event else { return }
        switch event {
        case .away(let since):
            logger.info("判定离开，最后一次输入或锁屏/入睡在 \(String(describing: since), privacy: .public)")
            controller.userAway(since: since)
        case .returned:
            logger.info("用户回来，重新开始一轮")
            controller.userReturned()
        }
    }
}
