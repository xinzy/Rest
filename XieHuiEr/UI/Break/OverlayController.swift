import AppKit
import os
import SwiftUI

/// 全屏遮罩（plan.md §4.2）：每块屏幕一个无边框窗口，覆盖所有桌面和全屏 App。
/// 显示期间拦截键盘输入；结束后淡出并把焦点还给休息前的 App。
@MainActor
final class OverlayController {
    private let controller: BreakController
    private var windows: [OverlayPanel] = []
    private var model: OverlayModel?
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    private var isShowing = false
    /// 休息开始时快照，避免休息中修改设置影响这次休息的结束音
    private var soundEnabled = true
    private let logger = Logger(subsystem: "com.shaozeng.xiehuier", category: "OverlayController")

    init(controller: BreakController) {
        self.controller = controller
        // 遮罩显示期间插拔屏幕或改分辨率时重建窗口
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
    }

    func show(_ active: ActiveBreak) {
        guard !isShowing else { return }
        let settings = controller.scheduler.settings
        let model = OverlayModel(
            active: active,
            tip: settings.tipsEnabled ? BreakTips.random(for: active.kind) : nil
        )
        model.onWaterRecorded = { [weak self] in
            // 数据记录在 S8 接入
            self?.logger.info("记录一杯水")
        }
        self.model = model
        soundEnabled = settings.soundEnabled
        previousApp = NSWorkspace.shared.frontmostApplication

        isShowing = true
        buildWindows()
        installKeyMonitor()
        for panel in windows {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        windows.first?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            for panel in windows {
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide(after outcome: BreakOutcome) {
        guard isShowing else { return }
        isShowing = false
        removeKeyMonitor()
        if outcome == .completed, soundEnabled {
            playSound()
        }

        let panels = windows
        windows.removeAll()
        model = nil
        guard !panels.isEmpty else {
            restoreFocus()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            for panel in panels {
                panel.animator().alphaValue = 0
            }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            for panel in panels {
                panel.orderOut(nil)
            }
            self?.restoreFocus()
        }
    }

    // MARK: - 窗口

    private func buildWindows() {
        guard let model else { return }
        let actions = OverlayView.Actions(
            skip: { [weak self] in self?.controller.skipBreak() },
            drinkWater: { [weak model] in model?.recordWater() }
        )
        for screen in NSScreen.screens {
            windows.append(makePanel(on: screen, model: model, actions: actions))
        }
    }

    private func makePanel(on screen: NSScreen, model: OverlayModel, actions: OverlayView.Actions) -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.animationBehavior = .none
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.becomesKeyOnlyIfNeeded = false
        panel.setFrame(screen.frame, display: false)

        let glass = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
        glass.material = .fullScreenUI
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.appearance = NSAppearance(named: .darkAqua)
        glass.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(
            rootView: OverlayView(controller: controller, model: model, actions: actions)
        )
        hosting.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: glass.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
        panel.contentView = glass
        panel.setFrame(screen.frame, display: false)
        return panel
    }

    private func screensChanged() {
        guard isShowing, model != nil else { return }
        let old = windows
        windows.removeAll()
        for panel in old {
            panel.orderOut(nil)
        }
        buildWindows()
        for panel in windows {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
        windows.first?.makeKeyAndOrderFront(nil)
        logger.info("屏幕配置变化，已重建遮罩窗口")
    }

    // MARK: - 键盘与焦点

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { _ in nil }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    private func restoreFocus() {
        guard let app = previousApp else { return }
        previousApp = nil
        guard !app.isTerminated, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        app.activate(options: [])
    }

    private func playSound() {
        guard let sound = NSSound(named: NSSound.Name("Glass")) else { return }
        sound.volume = 0.6
        sound.play()
    }
}

/// 遮罩窗口：可以成为 key window 以接收键盘，但不会激活 App；Esc 也不做任何事。
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {}
    override func cancelOperation(_ sender: Any?) {}
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
}
