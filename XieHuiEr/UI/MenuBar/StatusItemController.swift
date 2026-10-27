import AppKit

/// 菜单栏图标和面板：点击图标打开或收起面板；点击别处、按 Esc 或面板失去焦点时收起。
@MainActor
final class StatusItemController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private lazy var panel = PanelWindow(rootView: PanelView(onQuit: { [weak self] in self?.quit() }))
    private var eventMonitors: [Any] = []

    override init() {
        super.init()
        guard let button = statusItem.button else {
            preconditionFailure("NSStatusItem 没有 button")
        }
        button.image = Self.ringImage()
        button.setAccessibilityTitle("歇会儿")
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        panel.delegate = self
    }

    func showPanel() {
        guard let itemWindow = statusItem.button?.window, let screen = itemWindow.screen ?? NSScreen.main else {
            preconditionFailure("找不到菜单栏图标所在的屏幕")
        }
        panel.setFrameTopLeftPoint(PanelPlacement.topLeft(
            width: panel.frame.width, under: itemWindow.frame, visibleFrame: screen.visibleFrame))
        // 其他 App 处于全屏时，让菜单栏在面板打开期间保持显示（与系统菜单一致）
        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
        startEventMonitors()
    }

    func closePanel() {
        guard panel.isVisible else { return }
        stopEventMonitors()
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        closePanel()
    }

    @objc private func statusItemClicked() {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func startEventMonitors() {
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] _ in
            self?.closePanel()
        }) {
            eventMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.handleKeyDown(event) == true ? nil : event
        }) {
            eventMonitors.append(monitor)
        }
    }

    private func stopEventMonitors() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
    }

    /// 面板打开期间的快捷键：Esc 收起面板，⌘Q 退出
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == 53, modifiers.isEmpty {
            closePanel()
            return true
        }
        if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "q" {
            quit()
            return true
        }
        return false
    }

    /// 先收起面板再退出，保证 beginMenuTracking 有对应的 endMenuTracking
    private func quit() {
        closePanel()
        NSApp.terminate(nil)
    }

    /// 静态圆环，与「工作中」剩余时间满格时相同：18×18pt 模板图，半径 7pt，线宽 2pt
    private static func ringImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let ring = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 14, height: 14))
            ring.lineWidth = 2
            NSColor.black.setStroke()
            ring.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}

private extension Notification.Name {
    static let beginMenuTracking = Notification.Name("com.apple.HIToolbox.beginMenuTrackingNotification")
    static let endMenuTracking = Notification.Name("com.apple.HIToolbox.endMenuTrackingNotification")
}
