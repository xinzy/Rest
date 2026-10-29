import AppKit

/// 菜单栏图标和面板：图标随计时状态重绘；点击图标打开或收起面板；点击别处、按 Esc 或面板失去焦点时收起。
@MainActor
final class StatusItemController: NSObject, NSWindowDelegate {
    private let controller: BreakController
    private let water: WaterCenter
    private let store: DataStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private lazy var panel = PanelWindow(rootView: PanelView(controller: controller, water: water, actions: panelActions))
    private lazy var reportWindow = ReportWindowController(
        store: store,
        waterGoal: { [weak self] in self?.controller.scheduler.settings.waterGoal ?? 0 },
        onRecordsChanged: { [weak self] in self?.water.refresh(now: Date(), calendar: .current) }
    )
    private let settingsWindow = PlaceholderWindowController(title: "设置", message: "设置开发中（S10）")
    private var eventMonitors: [Any] = []
    private var iconStyle: RingIconStyle?
    /// 面板打开或收起后调用（预告浮窗据此让位）
    var onPanelVisibilityChanged: (() -> Void)?

    var isPanelVisible: Bool { panel.isVisible }

    init(controller: BreakController, water: WaterCenter, store: DataStore) {
        self.controller = controller
        self.water = water
        self.store = store
        super.init()
        guard let button = statusItem.button else {
            preconditionFailure("NSStatusItem 没有 button")
        }
        updateIcon()
        button.setAccessibilityTitle("歇会儿")
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        panel.delegate = self
    }

    /// 状态变化后调用：样式没变时不重绘
    func updateIcon() {
        let style = RingIconStyle(state: controller.scheduler.state, settings: controller.scheduler.settings, now: controller.now)
        guard style != iconStyle else { return }
        iconStyle = style
        statusItem.button?.image = RingIcon.image(style)
    }

    private var panelActions: PanelView.Actions {
        PanelView.Actions(
            breakNow: { [weak self] in self?.controller.breakNow() },
            pause: { [weak self] in self?.controller.pause($0) },
            resume: { [weak self] in self?.controller.resume() },
            drinkWater: { [weak self] in self?.water.drink(now: Date(), calendar: .current) },
            undoWater: { [weak self] in self?.water.undo(now: Date()) },
            openReport: { [weak self] in self?.showReport() },
            openSettings: { [weak self] in self?.open(self?.settingsWindow) },
            quit: { [weak self] in self?.quit() }
        )
    }

    private func open(_ window: PlaceholderWindowController?) {
        closePanel()
        window?.show()
    }

    /// 报表是正式窗口（S9），打开前先收起面板
    private func showReport() {
        closePanel()
        reportWindow.show()
    }

    #if DEBUG
    /// 调试用：打开报表并截取真实窗口（排查 ImageRenderer 与真实界面不一致的问题）
    func captureReport(to prefix: String) {
        closePanel()
        reportWindow.captureVariants(to: prefix)
    }
    #endif

    func showPanel() {
        guard let itemWindow = statusItem.button?.window, let screen = itemWindow.screen ?? NSScreen.main else {
            preconditionFailure("找不到菜单栏图标所在的屏幕")
        }
        // 内容高度随状态变化（例如暂停时的按钮），打开前按当前内容重新计算尺寸
        if let content = panel.contentView {
            panel.setContentSize(content.fittingSize)
        }
        panel.setFrameTopLeftPoint(PanelPlacement.topLeft(
            width: panel.frame.width, under: itemWindow.frame, visibleFrame: screen.visibleFrame))
        // 其他 App 处于全屏时，让菜单栏在面板打开期间保持显示（与系统菜单一致）
        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
        startEventMonitors()
        onPanelVisibilityChanged?()
    }

    func closePanel() {
        guard panel.isVisible else { return }
        stopEventMonitors()
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)
        onPanelVisibilityChanged?()
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

    /// 面板打开期间的快捷键：Esc 收起面板，⌘, 打开设置，⌘Q 退出
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
        if modifiers == .command, event.charactersIgnoringModifiers == "," {
            open(settingsWindow)
            return true
        }
        return false
    }

    /// 先收起面板再退出，保证 beginMenuTracking 有对应的 endMenuTracking
    private func quit() {
        closePanel()
        NSApp.terminate(nil)
    }
}

private extension Notification.Name {
    static let beginMenuTracking = Notification.Name("com.apple.HIToolbox.beginMenuTrackingNotification")
    static let endMenuTracking = Notification.Name("com.apple.HIToolbox.endMenuTrackingNotification")
}
