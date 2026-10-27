import AppKit
import os
import SwiftUI

/// 预告浮窗的窗口与生命周期（plan.md §4.2、§6 S5）。
/// 只在状态机的 .warning 期间显示；出现时不成为 key window，在其他 App 里打字不会被打断。
@MainActor
final class WarningHUDController {
    private let controller: BreakController
    private var window: WarningHUDWindow?
    /// 菜单栏面板打开时收起浮窗：两者都在右上角，会互相覆盖
    var isPanelVisible: () -> Bool = { false }
    private let logger = Logger(subsystem: "com.shaozeng.xiehuier", category: "WarningHUDController")

    init(controller: BreakController) {
        self.controller = controller
        // 浮窗显示期间插拔屏幕或改分辨率时重新定位
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
    }

    /// 每次状态刷新后调用：预告中显示，离开预告（推迟、暂停、开始休息等）立即收起
    func update() {
        guard case .warning = controller.scheduler.state, !isPanelVisible() else {
            hide()
            return
        }
        let window = self.window ?? makeWindow()
        guard !window.isVisible else { return }
        show(window)
    }

    func hide() {
        window?.orderOut(nil)
    }
}

private extension WarningHUDController {
    var actions: WarningHUDView.Actions {
        WarningHUDView.Actions(
            postpone: { [weak self] in self?.controller.postpone() },
            start: { [weak self] in self?.controller.startNow() }
        )
    }

    func makeWindow() -> WarningHUDWindow {
        let window = WarningHUDWindow(rootView: WarningHUDView(controller: controller, actions: actions))
        window.setContentSize(window.fittingSize)
        self.window = window
        return window
    }

    func show(_ window: WarningHUDWindow) {
        // 显示前按内容重新计算尺寸，定位也用这个尺寸（窗口 frame 可能还没跟上）
        let size = window.fittingSize
        window.setContentSize(size)
        position(window, size: size)
        // 不调用 makeKey，出现时不改变键盘焦点
        window.orderFrontRegardless()
        logger.info("显示预告浮窗")
    }

    func screensChanged() {
        guard let window, window.isVisible else { return }
        position(window, size: window.fittingSize)
    }

    /// 鼠标所在屏幕的右上角、菜单栏下方
    func position(_ window: WarningHUDWindow, size: NSSize) {
        guard let screen = Self.mouseScreen() else { return }
        window.setFrameTopLeftPoint(
            WarningHUDPlacement.topLeft(size: size, in: screen.visibleFrame)
        )
    }

    static func mouseScreen() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) } ?? NSScreen.main
    }
}

/// 预告浮窗的位置（原型 04）：右上角、菜单栏下方，离可见区域右边缘 10pt、下边缘 8pt
enum WarningHUDPlacement {
    static let margin: CGFloat = 10
    static let gap: CGFloat = 8

    /// 窗口左上角在屏幕坐标系（原点在左下）中的位置；屏幕太窄时贴住左边距
    static func topLeft(size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let x = max(visibleFrame.minX + margin, visibleFrame.maxX - margin - size.width)
        return CGPoint(x: x, y: visibleFrame.maxY - gap - size.height)
    }
}

/// 预告浮窗窗口：和菜单栏面板同样的圆角毛玻璃，但不会成为 key window。
private final class WarningHUDWindow: NSPanel {
    private static let cornerRadius: CGFloat = 15
    private let hosting: NSHostingView<AnyView>

    /// 内容的理想尺寸。窗口自身的 frame 在首次显示前可能还是 0，定位时要用这个值
    var fittingSize: NSSize { hosting.fittingSize }

    init(rootView: some View) {
        hosting = NSHostingView(rootView: AnyView(
            rootView.overlay {
                RoundedRectangle(cornerRadius: WarningHUDWindow.cornerRadius)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            }
        ))
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        // 出现在所有桌面空间，包括其他 App 的全屏空间
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = PanelWindow.roundedMask(radius: Self.cornerRadius)

        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        contentView = background
        setContentSize(fittingSize)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
