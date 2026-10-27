# S3 菜单栏图标和面板

- Changed files：XieHuiEr/App/AppDelegate.swift、XieHuiEr/App/BreakController.swift（新）、XieHuiEr/UI/MenuBar/PanelStatus.swift（新）、XieHuiEr/UI/MenuBar/RingIcon.swift（新）、XieHuiEr/UI/MenuBar/PanelView.swift、XieHuiEr/UI/MenuBar/StatusItemController.swift、XieHuiEr/UI/PlaceholderWindowController.swift（新）、XieHuiEr/Core/BreakScheduler.swift、XieHuiEr/Core/BreakSettings.swift
- Route or URL：菜单栏图标 → 面板（`-fastMode YES -openPanel YES`）
- Viewport：主屏 1728×1117 @2x（内建屏）；副屏 1920×1080 @1x，深色外观
- Artifact filename：
  - S3-panel-working.png：真实面板，工作中（快速模式，第 1/2 轮，下轮长休息）
  - S3-icon-working.png：副屏菜单栏中的图标（1x）
  - S3-icon-sequence.png：主屏图标每 2 秒截一次，共 30 张
  - S3-panel-states.png：用 ImageRenderer 渲染的面板（已暂停到 17:36 / 休息中 / 直到手动恢复 / 已暂停的深色版）
- Observed result：
  - 面板布局、字号和底板与原型 02、03 ② 一致；倒计时用等宽数字；暂停时第二个按钮变成「恢复计时」；休息中两个按钮都变灰。
  - 图标序列：进度环逐渐变短 → 圆环加中心点（预告 5 秒）→ 实心圆（休息 10 秒）→ 满环，然后再次变短。序列中有两张实心圆显得较大，原因是那两次截到的窗口是 22×22 px（其余为 48×50 px），拼图时被放大，属于截图造成的差异，不是图标本身的问题。
  - 与原型的差异：倒计时不足 10 分钟时分钟位补 0（如「00:49」），原型中只有两位数分钟的例子；喝水那一行在 S8 加入。
  - 用户手动验证（2026-10-27）：图标的变化序列、面板倒计时、第 2 轮显示长休息、暂停菜单的 4 个选项、恢复计时、立即休息、报表/设置占位窗口和 ⌘, 全部正常。
