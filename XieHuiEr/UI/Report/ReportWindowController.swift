import AppKit
import SwiftUI

/// 报表窗口（plan.md §2.5）：固定 880×680，只创建一次，关闭后再打开时复用；
/// 每次成为前台或切换分段时重新查库，不跟主循环每秒刷新。
@MainActor
final class ReportWindowController: NSObject, NSWindowDelegate {
    private let model: ReportModel
    private var window: NSWindow?

    init(store: DataStore, waterGoal: @escaping () -> Int, onRecordsChanged: @escaping () -> Void) {
        model = ReportModel(store: store, waterGoal: waterGoal, onRecordsChanged: onRecordsChanged)
        super.init()
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        model.reload()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.reload()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "报表"
        window.contentViewController = NSHostingController(rootView: ReportView(model: model))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
