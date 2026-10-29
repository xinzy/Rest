import AppKit
import SwiftUI

/// 设置窗口（plan.md §4.3）：固定 520×620，只创建一次，关闭后再打开时复用；
/// 打开时激活 App，并重新读一次系统里的登录项状态。
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private var window: NSWindow?

    init(
        settings: BreakSettings,
        store: SettingsStore,
        loginItem: LoginItem,
        onApply: @escaping (BreakSettings) -> Void
    ) {
        model = SettingsModel(settings: settings, store: store, loginItem: loginItem, onApply: onApply)
        super.init()
    }

    func show() {
        model.refreshLoginItem()
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.refreshLoginItem()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        // 和报表窗口一样：ScrollView 没有固有尺寸，必须给根视图固定大小，
        // 否则 NSHostingController 会把窗口缩成只包住标签栏的一条
        window.contentViewController = NSHostingController(
            rootView: SettingsView(model: model).frame(width: 520, height: 620)
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    #if DEBUG
    /// 调试用：把三个标签页逐个截图，外加一个超范围输入的报错样子（不依赖屏幕录制权限）
    func captureVariants(to prefix: String) {
        show()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        capture([
            ("general", .general, nil),
            ("rest", .rest, nil),
            ("water", .water, nil),
            ("water-error", .water, { self.model.commitWaterGoal(text: "200") }),
        ], at: 0, to: prefix)
    }

    private func capture(
        _ variants: [(String, SettingsModel.Tab, (() -> Void)?)],
        at index: Int,
        to prefix: String
    ) {
        guard index < variants.count else { return }
        let (name, tab, action) = variants[index]
        model.tab = tab
        action?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // 窗口是 key 时控件才以正常配色绘制，否则开关会画成灰色
            self.window?.makeKey()
            // 连标题栏一起截：原生标签栏画在标题栏区域，只截 contentView 会看不到
            if let window = self.window, let view = window.contentView?.superview ?? window.contentView,
               let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: URL(fileURLWithPath: "\(prefix)-\(name).png"))
            }
            self.capture(variants, at: index + 1, to: prefix)
        }
    }
    #endif
}
