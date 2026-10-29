# 进度

- 当前状态：设计已定稿（memory/plan.md）；S0–S10 已完成（S6–S10 待手动确认）；**下一步 S11 打包与验收**。
- 最后更新：2026-10-29

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
- [x] WorkHours：`state(now:calendar:)` 判断是否在工作时间内（开始时刻含、结束时刻不含），`nextStart` 算出下次开始（今天稍后 / 明天 / 下周一），`summary` 生成「周一至周五 09:00–19:00」（连续 3 天及以上用「至」，否则用「、」），`isValid` 保证不跨午夜
- [x] BreakSettings 增加 `workHours`（默认周一至周五 09:00–19:00）；快速模式里关闭，始终视为在工作时间内
- [x] 接入调度器：BreakController 注入 `currentWorkTime`，跟主循环每秒调用 `workTimeChanged`；进入工作时间时如果用户已离开，由 S6 的离开判定继续挡住这一轮
- [x] 面板「非工作时间」的第三行改为「工作时间：周一至周五 09:00–19:00」，没有勾选工作日时显示「未设置工作日」
- [x] 单元测试：WorkHours 11 个（开始/结束边界、上班前、周末、周五下班后、只勾一天、无工作日、开关关闭、文案格式、非法时间段）+ PanelStatus 2 个；共 90 个测试通过
- [x] 验证：.agent/visual/S7-panel-offhours.md（`-offHours YES -renderPanel` 渲染，与原型 03 ③ 对比一致）
- [ ] 待用户手动确认：非工作时间图标变灰、不出现预告浮窗；进入工作时间后从第一次键鼠操作开始新的一轮；设置界面在 S10 接入

## S8 数据记录
- [x] SwiftData：WaterRecord、BreakEvent、DataStore（按天汇总，`waterCounts(lastDays:now:calendar:)`）；数据库放 `~/Library/Application Support/XieHuiEr/Records.store`，打不开时退回内存库
- [x] 面板喝水行：+1、5 秒内撤销、距上次喝水、满 2 小时高亮（WaterCenter 管理撤销窗口，WaterStatus 负责文案和高亮）
- [x] 遮罩喝水按钮（每次休息只能点一次；已记录后变绿禁用并隐藏「距上次喝水」）
- [x] 调度器产生的事件写入 BreakEvent（完成、跳过、推迟、自动推迟）
- [x] 单元测试：DataStore 7 个（本地 0 点分天、按天汇总、删除后上次喝水回退、枚举字符串、撤销窗口、跨天归零）+ WaterStatus 10 个；共 107 个测试通过
- [x] 验证：.agent/visual/S8-water.md（`-renderPanel` / `-renderOverlay` 渲染六张图，与原型 02、03 ⑥、06 对比一致）；用 `open` 实测生成数据库文件
- [ ] 待用户手动确认：面板 +1 与 5 秒撤销、满 2 小时高亮、跨天归零、遮罩喝水只记一次；设置界面在 S10 接入

## S9 报表
- [x] ReportStats：喝水概览（今日、日均、达标、`goal=0` 时「未设目标」）、休息按天汇总（完成 ÷（完成 + 跳过），无记录时为「—」）、日期/时间/百分比文案，单元测试 14 个
- [x] DataStore 增加 `waterRecords(from:to:)`、`breakRecords(from:to:)`（含枚举字符串反向解析），单元测试 2 个；共 123 个测试通过
- [x] ReportWindowController：880×680、标题「报表」、`isReleasedWhenClosed=false`、打开时激活 App；每次成为前台重新查库，不每秒刷新
- [x] ReportView：内容区顶部「喝水 / 休息」「近 7 天 / 近 30 天」两个分段控件
- [x] 喝水页：3 张概览卡、Swift Charts 柱状图（达标实色 / 未达标 42%、目标虚线、今天底衬、点选日期）、当天明细左右切日、悬停垃圾桶立即删除（无二次确认）
- [x] 休息页：4 张概览卡、完成/跳过堆叠柱（柱顶总数）、每日明细表（最新在上、空白天灰显「—」）
- [x] 接线：StatusItemController 换成真实报表窗口，删除记录后同步刷新面板今日杯数
- [x] DEBUG `-renderReport <前缀>`：内存库造 30 天示例数据（近 7 天与原型 08、09 一致），渲染四个组合
- [x] DEBUG `-captureReport <前缀>`：打开真实窗口，用 `cacheDisplay` 逐组合截图（不依赖屏幕录制权限）
- [x] 验证：.agent/visual/S9-report.md（真实窗口四张图与原型 08、09 对比一致）；修复真实窗口内容区只有 428×45（`NSHostingController` 把窗口缩成只包住分段控件一条）与柱状图 x 轴只到「今天 0 点」导致今天的柱子被裁掉两个问题
- [ ] 待用户手动确认：窗口里切换分段与日期、点选柱状图、悬停删除记录并重算、30 天滚动

## S10 设置和开机自启
- [x] SettingsStore：整个 `BreakSettings` 编码成一个 JSON 存 UserDefaults 的 `breakSettings` 键；解码时逐字段 `decodeIfPresent`，缺字段/坏数据都回默认值（不认识的键忽略）
- [x] LoginItem：`SMAppService.mainApp` 注册/注销、`requiresApproval` 状态；首次启动默认注册（`loginItemConfigured` 只试一次），失败只记日志
- [x] SettingsModel：数值在失焦/回车时校验（5–120 分钟等 §4.3 范围），不合法只标红不保存；开关、工作日、时间段改动即时保存；工作时间校验开始早于结束；预告不短于推迟时标在预告上；登录项失败给黄色提示条文案
- [x] SettingsWindowController + SettingsView：520×620 固定窗口、原生 `TabView` 三页（通用 / 休息 / 喝水）、分组表单与脚注、长休息关闭时子项变灰、⌘, 打开且只创建一次
- [x] 接线：`BreakController.apply(settings:)`（休息中等这次结束、其他状态这一轮从头计时）；StatusItemController 用真实设置窗口替换占位窗口；AppDelegate 启动时从 SettingsStore 读设置并默认注册登录项
- [x] DEBUG `-renderSettings <前缀>`：打开真实窗口用 `cacheDisplay` 逐标签页截图（连标题栏，标签栏在标题栏区域）
- [x] 单元测试：SettingsStore 5 个（往返、缺键、坏数据、部分字段、未知字段）+ SettingsModel 8 个（合法即时生效、超范围保留旧值、非数字、预告与推迟关系、喝水目标边界、工作时间先后、工作日切换）；共 136 个测试通过
- [x] 验证：.agent/visual/S10-settings.md（与原型 07 对比）；深色外观、报错状态、原生标签栏位置均已记录
- [ ] 待用户手动确认：面板「设置… ⌘,」、改数值的生效时机、长休息关闭时子项灰显、登录项在 ad-hoc 签名下是否可用、失败时黄色提示条
- [ ] 端到端验收（verify.md 中的场景清单）

## S11 打包和验收
- [x] 产品名改成「歇会儿」：`PRODUCT_NAME: 歇会儿`、`EXECUTABLE_NAME`/`PRODUCT_MODULE_NAME` 仍为 `XieHuiEr`（Finder 里是 `歇会儿.app`，可执行文件与 Swift 模块保持 ASCII）；测试目标的 `TEST_HOST`/`BUNDLE_LOADER` 必须显式指向 `歇会儿.app`
- [x] 应用图标：`XieHuiEr/Resources/Assets.xcassets/AppIcon.appiconset`（圆角渐变方块 + 白色圆环 + 暂停符号，16–1024 共 10 个尺寸），`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
- [x] Release 构建：`xcodebuild -configuration Release -derivedDataPath build`，产物 `build/Build/Products/Release/歇会儿.app`（universal、ad-hoc 签名）
- [x] 安装到 `/Applications/歇会儿.app` 并启动验证；136 个测试通过
- [ ] 待用户手动确认：Finder / 登录项里的名称与图标、首次打开的系统放行

## 延后 / 待议
- S2 审查指出、尚未单独测试的子情形（逻辑由统一的条件判定覆盖，风险低）：预告/离开中点「立即休息」；会议推迟或离开中离开工作时间；预告、会议推迟、暂停、非工作时间、离开中修改设置；休息中调小长休息频率时先按旧设置计轮再截断。S10 前视情况补测
