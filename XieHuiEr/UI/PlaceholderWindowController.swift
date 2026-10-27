import AppKit
import SwiftUI

/// 报表、设置窗口的占位（正式窗口分别在 S9、S10 实现）。窗口只创建一次，关闭后再打开时复用；打开时激活 App。
@MainActor
final class PlaceholderWindowController {
    private let title: String
    private let message: String
    private var window: NSWindow?

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let content = Text(message)
            .foregroundStyle(.secondary)
            .frame(width: 480, height: 300)
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
