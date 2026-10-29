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
        // 必须给内容固定尺寸：ReportView 里的 ScrollView 没有固有高度，
        // 直接交给 NSHostingController 会把窗口缩成只包住顶部分段控件的一条
        window.contentViewController = NSHostingController(
            rootView: ReportView(model: model).frame(width: 880, height: 680)
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    #if DEBUG
    /// 调试用：把真实窗口的四个组合逐个截图（不依赖屏幕录制权限）
    func captureVariants(to prefix: String) {
        show()
        let variants: [(String, ReportModel.Tab, ReportModel.Span)] = [
            ("water-7", .water, .week),
            ("water-30", .water, .month),
            ("rest-7", .rest, .week),
            ("rest-30", .rest, .month),
        ]
        capture(variants, at: 0, to: prefix)
    }

    private func capture(_ variants: [(String, ReportModel.Tab, ReportModel.Span)], at index: Int, to prefix: String) {
        guard index < variants.count else { return }
        let (name, tab, span) = variants[index]
        model.tab = tab
        model.span = span
        model.reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if let window = self.window, let view = window.contentView,
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
