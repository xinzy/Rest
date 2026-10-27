import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var breakController: BreakController?
    private var statusItemController: StatusItemController?

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
        breakController.onChange = { [weak controller] in controller?.updateIcon() }
        breakController.start()
        self.breakController = breakController
        statusItemController = controller
        #if DEBUG
        // 调试用：启动参数 -openPanel YES 让面板在启动后直接打开，不点击图标也能检查面板。
        // 刚启动时菜单栏图标还在排版（窗口先在屏幕外，再到屏幕边缘），等 1 秒位置稳定后再打开。
        if UserDefaults.standard.bool(forKey: "openPanel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { controller.showPanel() }
        }
        #endif
    }

    /// 设置的持久化在 S10 实现，目前用默认值
    private static func initialSettings() -> BreakSettings {
        #if DEBUG
        // 调试用：启动参数 -fastMode YES 把所有时长换成秒级（见 verify.md）
        if UserDefaults.standard.bool(forKey: "fastMode") { return .fastMode }
        #endif
        return BreakSettings()
    }
}
