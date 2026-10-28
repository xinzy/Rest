# S7 非工作时间面板状态

- Changed files：XieHuiEr/Core/WorkHours.swift（新）、XieHuiEr/Core/BreakSettings.swift、XieHuiEr/App/BreakController.swift、XieHuiEr/App/AppDelegate.swift、XieHuiEr/UI/MenuBar/PanelStatus.swift、XieHuiErTests/WorkHoursTests.swift（新）、XieHuiErTests/PanelStatusTests.swift
- Route or URL：菜单栏图标 → 面板；调试参数 `-offHours YES -renderPanel <路径前缀>` 渲染 PNG
- Viewport：面板宽 320pt，渲染 2x，浅色外观
- Artifact filename：S7-panel-offhours.png（非工作时间）
- Observed result：
  - 状态区显示「非工作时间」、副标题「明天 09:00 开始提醒」、第三行「工作时间：周一至周五 09:00–19:00」，与原型 03 ③ 一致；第三行单行显示、没有被截断。
  - 「立即休息」可用，「暂停」置灰并显示「非工作时间不可用」，图标变灰，与原型一致。
  - 副标题与原型不同：原型画的是周末场景（「周一 09:00 开始提醒」），这次渲染是周三 10:03，下次开始是周四 09:00，所以显示「明天 09:00 开始提醒」，文案逻辑与原型相同。
  - 差异只有渲染用浅色实底代替了窗口的毛玻璃；本机终端进程没有屏幕录制权限，截图由 ImageRenderer 生成。
  - 待用户手动确认：把系统时间或工作时段改到当前时刻之外后，菜单栏图标变灰、不再出现预告浮窗，进入工作时间后从第一次键鼠操作开始新的一轮。
