import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var breakController: BreakController?
    private var statusItemController: StatusItemController?
    private var overlayController: OverlayController?
    private var warningHUDController: WarningHUDController?
    private var meetingDetector: MeetingDetector?
    private var presenceMonitor: PresenceMonitor?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 运行单元测试时，App 只是测试的宿主，不创建菜单栏图标
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let breakController = BreakController(settings: Self.initialSettings())
        let controller = StatusItemController(controller: breakController)
        let overlay = OverlayController(controller: breakController)
        let hud = WarningHUDController(controller: breakController)
        // 会议检测：到点时麦克风或摄像头被占用就推迟休息
        let meeting = MeetingDetector()
        breakController.isInMeeting = { [weak meeting] in meeting?.isInMeeting ?? false }
        // 离开检测：无操作、锁屏、睡眠
        let presence = PresenceMonitor(controller: breakController)
        // 工作时间：按设置判断，跟主循环每秒一起检查
        breakController.currentWorkTime = { [weak breakController] now in
            guard let breakController else { return .on }
            return breakController.scheduler.settings.workHours.state(now: now, calendar: .current)
        }
        controller.onPanelVisibilityChanged = { [weak hud] in hud?.update() }
        hud.isPanelVisible = { [weak controller] in controller?.isPanelVisible ?? false }
        breakController.onChange = { [weak controller, weak hud] in
            controller?.updateIcon()
            hud?.update()
        }
        breakController.onBreakStarted = { [weak controller, weak overlay, weak hud] active in
            hud?.hide()
            controller?.closePanel()
            overlay?.show(active)
        }
        breakController.onBreakEnded = { [weak overlay] record in
            overlay?.hide(after: record.outcome)
        }
        breakController.start()
        presence.start()
        self.breakController = breakController
        statusItemController = controller
        overlayController = overlay
        warningHUDController = hud
        meetingDetector = meeting
        presenceMonitor = presence
        #if DEBUG
        // 调试用：启动参数 -openPanel YES 让面板在启动后直接打开，不点击图标也能检查面板。
        // 刚启动时菜单栏图标还在排版（窗口先在屏幕外，再到屏幕边缘），等 1 秒位置稳定后再打开。
        if UserDefaults.standard.bool(forKey: "openPanel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { controller.showPanel() }
        }
        // 调试用：启动参数 -showOverlay YES 立即开始一次休息，方便检查遮罩。
        if UserDefaults.standard.bool(forKey: "showOverlay") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { breakController.breakNow() }
        }
        // 调试用：启动参数 -renderOverlay <路径前缀> 把遮罩渲染成 PNG（没有屏幕录制权限时核对界面）。
        if let prefix = UserDefaults.standard.string(forKey: "renderOverlay") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Self.renderOverlay(to: prefix) }
        }
        // 调试用：启动参数 -renderWarningHUD <路径前缀> 把预告浮窗渲染成 PNG。
        if let prefix = UserDefaults.standard.string(forKey: "renderWarningHUD") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Self.renderWarningHUD(to: prefix) }
        }
        // 调试用：启动参数 -offHours YES 把状态固定成非工作时间，方便查看面板的该状态。
        if UserDefaults.standard.bool(forKey: "offHours") {
            breakController.currentWorkTime = { now in
                .off(nextStart: WorkHours().nextStart(now: now, calendar: .current))
            }
        }
        // 调试用：启动参数 -renderPanel <路径前缀> 把面板渲染成 PNG。
        if let prefix = UserDefaults.standard.string(forKey: "renderPanel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { Self.renderPanel(breakController, to: prefix) }
        }
        #endif
    }

    #if DEBUG
    /// 用 ImageRenderer 渲染短休息和长休息的遮罩（深色实底代替窗口的毛玻璃背景）。
    @MainActor
    private static func renderOverlay(to prefix: String) {
        let now = Date()
        let controller = BreakController(settings: BreakSettings())
        let breaks: [(String, ActiveBreak)] = [
            ("short", ActiveBreak(kind: .short, trigger: .scheduled, startedAt: now - 6, endsAt: now + 24)),
            ("long", ActiveBreak(kind: .long, trigger: .scheduled, startedAt: now - 48, endsAt: now + 252)),
        ]
        for (name, active) in breaks {
            let model = OverlayModel(active: active, tip: BreakTips.random(for: active.kind))
            let view = ZStack {
                Color(white: 0.18)
                OverlayView(controller: controller, model: model, actions: .init(skip: {}, drinkWater: {}))
            }
            .frame(width: 1440, height: 900)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                continue
            }
            try? png.write(to: URL(fileURLWithPath: "\(prefix)-\(name).png"))
        }
    }

    /// 用 ImageRenderer 渲染面板（浅色实底代替窗口的毛玻璃背景）。
    @MainActor
    private static func renderPanel(_ controller: BreakController, to prefix: String) {
        let view = ZStack {
            Color(white: 0.96)
            PanelView(controller: controller, actions: .init(
                breakNow: {}, pause: { _ in }, resume: {}, openReport: {}, openSettings: {}, quit: {}
            ))
            .padding(12)
        }
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: "\(prefix).png"))
    }

    /// 用 ImageRenderer 渲染预告浮窗的短休息和长休息两种样子（浅色实底代替窗口的毛玻璃背景）。
    @MainActor
    private static func renderWarningHUD(to prefix: String) {
        let now = Date()
        let settings = BreakSettings()
        let previews: [(String, BreakKind, TimeInterval)] = [("short", .short, 28), ("long", .long, 26)]
        for (name, kind, remaining) in previews {
            let status = WarningHUDStatus(kind: kind, settings: settings, now: now, dueAt: now + remaining)
            let view = ZStack(alignment: .topTrailing) {
                Color(white: 0.93)
                WarningHUDContent(status: status, actions: .init(postpone: {}, start: {}))
                    .padding([.top, .trailing], 12)
            }
            .frame(width: 420, height: 200)
            .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                continue
            }
            try? png.write(to: URL(fileURLWithPath: "\(prefix)-\(name).png"))
        }
    }
    #endif

    /// 设置的持久化在 S10 实现，目前用默认值
    private static func initialSettings() -> BreakSettings {
        #if DEBUG
        // 调试用：启动参数 -fastMode YES 把所有时长换成秒级（见 verify.md）
        if UserDefaults.standard.bool(forKey: "fastMode") { return .fastMode }
        #endif
        return BreakSettings()
    }
}
