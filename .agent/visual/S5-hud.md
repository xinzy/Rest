# S5 预告浮窗

- Changed files：XieHuiEr/App/AppDelegate.swift、XieHuiEr/App/BreakController.swift、XieHuiEr/UI/MenuBar/StatusItemController.swift、XieHuiEr/UI/MenuBar/PanelWindow.swift（圆角蒙版改为可复用）、XieHuiEr/UI/Break/WarningHUDStatus.swift（新）、XieHuiEr/UI/Break/WarningHUDView.swift（新）、XieHuiEr/UI/Break/WarningHUDController.swift（新）、XieHuiErTests/WarningHUDTests.swift（新）
- Route or URL：状态机进入预告时自动显示（快速模式 T+55 秒）；调试参数 `-renderWarningHUD <路径前缀>` 渲染 PNG
- Viewport：渲染画布 420×200 @2x，浅色外观；实测主屏 1728×1117 @2x、副屏 1920×1080 @1x
- Artifact filename：
  - S5-hud-short.png：短休息，28 秒后开始（环 28/30）
  - S5-hud-long.png：长休息，26 秒后开始（figure.walk）
- Observed result：
  - 尺寸、圆角、44pt 进度环、标题 15pt semibold、副标题 12.5pt secondary、两列按钮（推迟灰底 / 立即开始强调色）与原型 04 一致；差异只有渲染用浅色实底代替了窗口的毛玻璃。
  - 本机终端进程没有屏幕录制权限，真实毛玻璃无法截屏，截图由 ImageRenderer 生成。
  - 实测（`-fastMode YES`，T+55 秒）：预告浮窗窗口 330×113、layer=25，位于主屏右上角，CG 坐标 x=1388、y=159；右边缘 1718，距屏幕右边 10pt，顶部在菜单栏可见区域下方 8pt。
  - 实测中发现并修复：首次显示时位置偏右、部分超出屏幕，原因是窗口 frame 在显示前还是 0，定位时用了它。改为用内容 hosting view 的 `fittingSize` 计算尺寸和位置。
  - 待用户手动确认：打字时浮窗出现不抢焦点、第一次点击按钮即可生效、推迟/立即开始、副屏定位、其他 App 全屏时仍出现、面板打开时浮窗让位。
