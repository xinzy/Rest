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
    private var dataStore: DataStore?
    private var waterCenter: WaterCenter?

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
        // 喝水和休息记录存 SwiftData，仅保存在本机
        let store = DataStore(container: DataStore.makeContainer())
        let water = WaterCenter(store: store)
        let controller = StatusItemController(controller: breakController, water: water, store: store)
        let overlay = OverlayController(controller: breakController, water: water)
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
        breakController.onChange = { [weak controller, weak hud, weak water] in
            controller?.updateIcon()
            hud?.update()
            // 跨天后重新查库，算出新一天的杯数
            water?.refreshIfNeeded(now: Date(), calendar: .current)
        }
        breakController.onBreakRecorded = { [weak store] record in
            store?.addBreakEvent(record)
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
        dataStore = store
        waterCenter = water
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
        // 调试用：启动参数 -renderReport <路径前缀> 把报表的四个组合渲染成 PNG。
        if let prefix = UserDefaults.standard.string(forKey: "renderReport") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Self.renderReport(to: prefix) }
        }
        // 调试用：启动参数 -captureReport <路径前缀> 截取真实报表窗口（含滚动区和分段控件）。
        if let prefix = UserDefaults.standard.string(forKey: "captureReport") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { controller.captureReport(to: prefix) }
        }
        #endif
    }

    #if DEBUG
    /// 用 ImageRenderer 渲染遮罩：短休息（默认）、长休息（已记录喝水）、高亮三种样子
    /// （深色实底代替窗口的毛玻璃背景）。
    @MainActor
    private static func renderOverlay(to prefix: String) {
        let now = Date()
        let controller = BreakController(settings: BreakSettings())
        let recent = previewWater(lastDrinkAgo: 80 * 60, count: 2)
        let thirsty = previewWater(lastDrinkAgo: 2 * 60 * 60 + 10 * 60, count: 1)
        let previews: [(String, ActiveBreak, WaterCenter, Bool)] = [
            ("short", ActiveBreak(kind: .short, trigger: .scheduled, startedAt: now - 6, endsAt: now + 24), recent, false),
            ("long", ActiveBreak(kind: .long, trigger: .scheduled, startedAt: now - 48, endsAt: now + 252), recent, true),
            ("hot", ActiveBreak(kind: .short, trigger: .scheduled, startedAt: now - 6, endsAt: now + 24), thirsty, false),
        ]
        for (name, active, water, recorded) in previews {
            let model = OverlayModel(active: active, tip: BreakTips.random(for: active.kind))
            if recorded { model.recordWater() }
            let view = ZStack {
                Color(white: 0.18)
                OverlayView(controller: controller, model: model, water: water, actions: .init(skip: {}, drinkWater: {}))
            }
            .frame(width: 1440, height: 900)
            write(view, to: "\(prefix)-\(name).png")
        }
    }

    /// 用 ImageRenderer 渲染面板的三种喝水状态（浅色实底代替窗口的毛玻璃背景）。
    @MainActor
    private static func renderPanel(_ controller: BreakController, to prefix: String) {
        let undoWater = previewWater(lastDrinkAgo: 80 * 60, count: 3)
        undoWater.drink(now: Date(), calendar: .current)
        let variants: [(String, WaterCenter)] = [
            ("normal", previewWater(lastDrinkAgo: 80 * 60, count: 3)),
            ("alert", previewWater(lastDrinkAgo: 2 * 60 * 60 + 10 * 60, count: 2)),
            ("undo", undoWater),
        ]
        for (name, water) in variants {
            let view = ZStack {
                Color(white: 0.96)
                PanelView(controller: controller, water: water, actions: .init(
                    breakNow: {}, pause: { _ in }, resume: {}, drinkWater: {}, undoWater: {},
                    openReport: {}, openSettings: {}, quit: {}
                ))
                .padding(12)
            }
            .environment(\.colorScheme, .light)
            write(view, to: "\(prefix)-\(name).png")
        }
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
            write(view, to: "\(prefix)-\(name).png")
        }
    }

    /// 用 ImageRenderer 渲染报表的四个组合（880×680 的窗口内容）；
    /// 内存库里的近 7 天数据与原型 08、09 一致，往前补齐到 30 天。
    @MainActor
    private static func renderReport(to prefix: String) {
        let model = ReportModel(store: makeSampleStore(), waterGoal: { 8 }, onRecordsChanged: {})
        let variants: [(String, ReportModel.Tab, ReportModel.Span)] = [
            ("water-7", .water, .week),
            ("water-30", .water, .month),
            ("break-7", .rest, .week),
            ("break-30", .rest, .month),
        ]
        for (name, tab, span) in variants {
            model.tab = tab
            model.span = span
            model.reload()
            // ImageRenderer 渲染不了 ScrollView 和分段控件，这里直接渲染页面内容
            let view = ZStack(alignment: .topLeading) {
                Color(white: 0.96)
                Group {
                    switch tab {
                    case .water: WaterReportView(model: model)
                    case .rest: BreakReportView(model: model)
                    }
                }
                .padding(20)
                .frame(width: 880, alignment: .leading)
            }
            .environment(\.colorScheme, .light)
            write(view, to: "\(prefix)-\(name).png")
        }
    }

    /// 报表截图用的内存库：近 7 天与原型一致，往前补齐到 30 天
    @MainActor
    private static func makeSampleStore() -> DataStore {
        let store = DataStore(container: DataStore.makeContainer(inMemory: true))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 从最早到最近，每天杯数；最后 7 天是原型的 [6, 8, 9, 5, 8, 4, 3]
        let waterCounts = [
            6, 7, 8, 6, 7, 5, 6, 8, 9, 5,
            7, 6, 8, 5, 7, 9, 6, 8, 4, 6,
            7, 8, 6,
            6, 8, 9, 5, 8, 4, 3,
        ]
        for (index, count) in waterCounts.enumerated() {
            let day = calendar.date(byAdding: .day, value: index - (waterCounts.count - 1), to: today) ?? today
            for cup in 0..<count {
                store.addWater(at: day.addingTimeInterval(8 * 3600 + Double(cup) * 32 * 60))
            }
        }

        // 最后 7 天的（完成、跳过、推迟、开会自动推迟）与原型 09 的明细表一致
        let recentBreaks = [
            (12, 2, 3, 1), (14, 1, 2, 2), (11, 3, 4, 0), (0, 0, 0, 0),
            (0, 0, 0, 0), (13, 1, 2, 3), (2, 0, 1, 0),
        ]
        let olderBreaks = [
            (9, 1, 2, 0), (12, 2, 1, 1), (10, 0, 3, 0), (0, 0, 0, 0),
            (0, 0, 0, 0), (11, 2, 2, 1), (13, 1, 2, 2),
        ]
        var breakData: [(Int, Int, Int, Int)] = []
        for index in 0..<23 {
            breakData.append(olderBreaks[index % olderBreaks.count])
        }
        breakData.append(contentsOf: recentBreaks)

        for (index, data) in breakData.enumerated() {
            let day = calendar.date(byAdding: .day, value: index - (breakData.count - 1), to: today) ?? today
            let (completed, skipped, postponed, autoDeferred) = data
            for item in 0..<completed {
                store.addBreakEvent(BreakRecord(
                    at: day.addingTimeInterval(9.5 * 3600 + Double(item) * 35 * 60),
                    kind: item % 4 == 3 ? .long : .short, outcome: .completed, trigger: .scheduled))
            }
            for item in 0..<skipped {
                store.addBreakEvent(BreakRecord(
                    at: day.addingTimeInterval(10 * 3600 + Double(item) * 35 * 60),
                    kind: .short, outcome: .skipped, trigger: .scheduled))
            }
            for item in 0..<postponed {
                store.addBreakEvent(BreakRecord(
                    at: day.addingTimeInterval(18 * 3600 + Double(item) * 10 * 60),
                    kind: .short, outcome: .postponed, trigger: .scheduled))
            }
            for item in 0..<autoDeferred {
                store.addBreakEvent(BreakRecord(
                    at: day.addingTimeInterval(19 * 3600 + Double(item) * 5 * 60),
                    kind: .short, outcome: .autoDeferred, trigger: .scheduled))
            }
        }
        return store
    }

    /// 调试渲染用的内存库和喝水状态：最近一杯在 lastDrinkAgo 之前，更早的每 30 分钟一杯
    @MainActor
    private static func previewWater(lastDrinkAgo: TimeInterval, count: Int) -> WaterCenter {
        let store = DataStore(container: DataStore.makeContainer(inMemory: true))
        let now = Date()
        for index in 0..<count {
            store.addWater(at: now - lastDrinkAgo - Double(index) * 30 * 60)
        }
        return WaterCenter(store: store, now: now)
    }

    @MainActor
    private static func write(_ view: some View, to path: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
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
