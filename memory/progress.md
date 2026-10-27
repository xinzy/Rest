# 进度

- 当前状态：设计已定稿（memory/plan.md）；S0–S6 已完成（S6 待手动确认）；**下一步 S7 工作时间段**。
- 最后更新：2026-10-27

## S0 HTML 原型
- [x] 写设计文档（memory/）
- [x] 制作原型（design/mockups/index.html）：菜单栏图标的各种状态、面板（含 8 种状态）、预告浮窗、遮罩（短休息和长休息）、设置（3 个标签页）、报表（喝水和休息）
- [x] 截图，保存到 design/mockups/screenshots/（9 张，2 倍分辨率；capture.sh 截图前会检查内容是否超出画框）
- [x] 用户确认原型（2026-10-27，无修改）

## S1 工程骨架
- [x] 征得用户同意后执行 `git init`，并添加 .gitignore（忽略 build/、xcuserdata/、.DS_Store，以及由 project.yml 生成的 XieHuiEr.xcodeproj/）
- [x] 编写 project.yml：App 目标（macOS 14、LSUIElement、显示名「歇会儿」、Bundle ID，版本号取自 MARKETING_VERSION）和单元测试目标
- [x] StatusItemController：静态圆环图标、占位面板（PanelWindow + PanelView）、退出功能；面板定位逻辑 PanelPlacement 有 3 个单元测试
- [x] 构建、运行并截图验证：.agent/visual/S1-panel.md；用户在两块屏幕上手动验证通过（2026-10-27）
- [x] 运行时发现并修复：退出前先收起面板，让 begin/endMenuTracking 成对；DEBUG 参数 `-openPanel` 改为延迟 1 秒打开（刚启动时图标还没排好）

## S2 计时状态机（纯逻辑和单元测试）
- [x] BreakSettings：默认值、取值范围校验（含「预告 < 推迟」）、快速模式参数
- [x] BreakScheduler：状态、事件、状态转移、轮次规则（见 plan.md §3），覆盖 §3.2 的全部转移。会议、离开、工作时间由调用方通过事件或参数传入，检测本身在 S6、S7 实现
- [x] 单元测试（37 个）：到点 → 预告 → 休息 → 完成；推迟；跳过（倒计时已走完时按完成）；长休息节奏（包括跳过后下一轮补上）；立即休息；暂停与恢复；修改设置；会议推迟与复查；离开与轮次清零；进入和离开工作时间。注入 4 处错误都能被抓到；独立审查后修复 2 个边界问题（2026-10-27）

## S3 菜单栏图标和面板
- [x] RingIcon：RingIconStyle 根据状态得出 5 种样式（进度按 1% 取整，样式不变时不重绘），按原型绘制 18×18pt 模板图
- [x] 把每秒一次的主循环接入调度器：BreakController（Timer 加在 .common 模式，菜单展开时照常计时）；休息记录暂时只写日志（S8 存库）；DEBUG `-fastMode YES`
- [x] PanelView：状态区的文案由 PanelStatus 计算（7 种状态都有单元测试）、立即休息、暂停菜单（PauseOption 有测试）、恢复计时，以及报表、设置（含 ⌘,）、退出；报表和设置先用占位窗口
- [x] 验证：54 个测试通过；截图见 .agent/visual/S3-panel.md；用户手动验证通过（2026-10-27）

## S4 全屏遮罩
- [x] 休息开始时收起面板（BreakController 新增 onBreakStarted/onBreakEnded 回调，AppDelegate 里先 closePanel 再显示遮罩）
- [x] OverlayController：每块屏幕一个 `.borderless + .nonactivatingPanel` 窗口（level `.screenSaver`、加入所有 Space 和全屏 App、跨屏常驻），屏幕配置变化时重建窗口，显示前记录前台 App、隐藏后用 `activate(options: [])` 归还焦点，本地 keyDown/keyUp 监视器加窗口内重写拦截键盘（Esc 不跳过）
- [x] OverlayView：休息类型胶囊、240pt 倒计时环（72pt 等宽数字）、随机休息建议（BreakTips，休息开始时选定）、跳过按钮、喝水按钮（可点击，本次休息只能记一次，S8 接数据）
- [x] 休息结束提示音：系统 Glass，音量 0.6；仅自然完成时播放，跳过不播
- [x] 设置：BreakSettings 新增 soundEnabled、tipsEnabled（默认开）
- [x] 单元测试：OverlayStatus、BreakTips、OverlayModel（喝水只记一次）、BreakController 回调与 skipBreak，共 61 个测试通过
- [x] 验证：.agent/visual/S4-overlay.md（ImageRenderer 截图核对视觉；遮罩窗口双屏实测出现和消失）

## S5 预告浮窗
- [x] WarningHUD（不激活 App 的 NSPanel，显示在鼠标所在屏幕的右上角）、推迟、立即开始
- [x] WarningHUDStatus：标题「N 秒后开始短/长休息」、副标题、「推迟 X」、进度环比例，有单元测试
- [x] 窗口不会成为 key window（`canBecomeKey = false`，显示时不调用 `makeKey`）；只在 `.warning` 期间显示，离开预告立即收起；菜单栏面板打开时让位
- [x] 屏幕配置变化时重新定位；`-renderWarningHUD` 渲染截图
- [x] 验证：69 个测试通过；截图和实测见 .agent/visual/S5-hud.md（快速模式下浮窗出现在主屏右上角，330×113，右边缘距屏幕 10pt、顶部在菜单栏下方 8pt）
- [ ] 待用户手动确认：打字时不抢焦点、首次点击按钮即生效、推迟/立即开始、副屏定位、其他 App 全屏

## S6 离开检测和会议推迟
- [x] IdleMonitor：用 `CGEventSource.secondsSinceLastEventType`（任意输入）读无操作时长；用 `IOPMCopyAssertionsStatus` 读 `PreventUserIdleDisplaySleep` / `NoDisplaySleepAssertion`。用 `caffeinate -d` 实测读数从 0 变 1，逻辑正确
- [x] SessionMonitor：`DistributedNotificationCenter` 的 `com.apple.screenIsLocked` / `screenIsUnlocked`，`NSWorkspace` 的 `willSleep` / `didWake`
- [x] MeetingDetector：麦克风（CoreAudio，输入声道 + `kAudioDevicePropertyDeviceIsRunningSomewhere`）、摄像头（CoreMediaIO，`kCMIODevicePropertyDeviceIsRunningSomewhere`），都不采集音视频、不需要权限
- [x] 接入 BreakController.tick 的 isInMeeting（由 AppDelegate 接到 MeetingDetector）；面板会议状态副标题按原型保持「麦克风或摄像头正在使用」，不区分具体设备
- [x] 单元测试：PresenceTracker 8 个（无操作阈值、防息屏断言、锁屏/解锁、睡眠/唤醒、保留更早时间、解锁后从回来时刻重算）；共 77 个测试通过
- [ ] 待用户手动确认（快速模式）：无操作 20 秒判定离开、再操作即回来；锁屏/解锁；睡眠/唤醒；播放视频不离开；录音时到点推迟并每 5 秒复查；全程没有权限弹窗

## S7 工作时间段
- [ ] WorkHours：判断当前是否在工作时间内，计算下次开始时间
- [ ] 接入调度器：工作时间变化时调用 workTimeChanged（调度器一侧的状态转移已在 S2 测试）
- [ ] 面板「非工作时间」状态的第三行目前写的是「非工作时间不提醒休息」，改为显示工作时间（原型 03 ③：「工作时间：周一至周五 09:00–19:00」）
- [ ] 单元测试：周末、边界时刻、跨天

## S8 数据记录
- [ ] SwiftData：WaterRecord、BreakEvent、Store（按天汇总）
- [ ] 面板喝水行：+1、5 秒内撤销、距上次喝水、满 2 小时高亮
- [ ] 遮罩喝水按钮（每次休息只能点一次）
- [ ] 调度器产生的事件写入 BreakEvent
- [ ] 单元测试：按天汇总（使用内存数据库）

## S9 报表
- [ ] 报表窗口；喝水页（概览、柱状图和目标线、每日明细和删除）
- [ ] 休息页（概览、堆叠柱状图、每日明细表）
- [ ] DEBUG 模式下的示例数据，用于截图

## S10 设置和开机自启
- [ ] 设置窗口的三个标签页、取值范围校验、修改后立即生效
- [ ] SMAppService 登录项（实测 ad-hoc 签名下是否可用）
- [ ] 端到端验收（verify.md 中的场景清单）

## 延后 / 待议
- S2 审查指出、尚未单独测试的子情形（逻辑由统一的条件判定覆盖，风险低）：预告/离开中点「立即休息」；会议推迟或离开中离开工作时间；预告、会议推迟、暂停、非工作时间、离开中修改设置；休息中调小长休息频率时先按旧设置计轮再截断。S10 前视情况补测
