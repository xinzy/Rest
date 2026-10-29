# S9 报表

- Changed files：XieHuiEr/Core/ReportStats.swift（新）、XieHuiEr/UI/Report/ReportWindowController.swift（新）、ReportModel.swift（新）、ReportView.swift（新）、WaterReportView.swift（新）、BreakReportView.swift（新）、XieHuiEr/Data/BreakEvent.swift、XieHuiEr/Data/DataStore.swift、XieHuiEr/UI/MenuBar/StatusItemController.swift、XieHuiEr/App/AppDelegate.swift、XieHuiErTests/ReportStatsTests.swift（新）、XieHuiErTests/DataStoreTests.swift
- Route or URL：面板「报表…」→ 880×680 独立窗口；调试参数 `-captureReport <前缀>` 打开真实窗口并逐个组合截图（不依赖屏幕录制权限）
- Viewport：窗口内容 880×680，截图 1x，跟随系统外观（本次抓图是深色）
- Artifact filename：
  - S9-report-window-water-7.png（3 张卡、7 根柱、目标线、今日底衬、当天明细）
  - S9-report-window-water-30.png（30 根柱、每 5 天一个日期）
  - S9-report-window-rest-7.png（4 张卡、堆叠柱、7 行明细）
  - S9-report-window-rest-30.png（30 天堆叠柱与明细）
- Observed result：
  - 真实窗口里分段控件、概览卡、图表、明细都完整；图例、目标虚线、今日底衬与原型 08、09 一致；明细最新一天在上，无记录的一天整行灰显、「—」。
  - 修复一（窗口尺寸）：`ReportView` 里的 `ScrollView` 没有固有高度，直接把 `ReportView` 交给 `NSHostingController` 会把窗口缩成只包住顶部分段控件的一条（实测内容区只有 428×45），看起来就是「只有两个分段控件、下面全空」。现在给根视图固定 `.frame(width: 880, height: 680)`。
  - 修复二（柱子被裁）：柱子的 x 范围是 `[当天 0 点, 次日 0 点)`，x 轴上限原来设成「今天 0 点」，今天的柱子被整根裁掉；只有今天有记录时整张图看起来是空的。现在上限延到次日，30 天模式再延一天，避免最右日期标签被裁。
- 待用户手动确认：窗口里切换「喝水 / 休息」「近 7 天 / 近 30 天」；柱状图点选日期后明细切换；明细行悬停出现垃圾桶、点击立即删除并重算概览与图表；30 天时整页滚动。
