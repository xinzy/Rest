import AppKit

/// 锁屏、解锁、睡眠、唤醒（plan.md §3.3）。只接收通知，不需要额外权限。
@MainActor
final class SessionMonitor {
    var onLock: ((Date) -> Void)?
    var onUnlock: ((Date) -> Void)?
    var onSleep: ((Date) -> Void)?
    var onWake: ((Date) -> Void)?

    private var observers: [NSObjectProtocol] = []

    init() {
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onLock?(Date()) }
        })
        observers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onUnlock?(Date()) }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onSleep?(Date()) }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onWake?(Date()) }
        })
    }
}
