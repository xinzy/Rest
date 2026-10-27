# S4 全屏遮罩

- Changed files：XieHuiEr/App/AppDelegate.swift、XieHuiEr/App/BreakController.swift、XieHuiEr/Core/BreakSettings.swift、XieHuiEr/Core/BreakState.swift、XieHuiEr/UI/Break/BreakTips.swift（新）、XieHuiEr/UI/Break/OverlayStatus.swift（新）、XieHuiEr/UI/Break/OverlayView.swift（新）、XieHuiEr/UI/Break/OverlayController.swift（新）、XieHuiErTests/OverlayStatusTests.swift（新）
- Route or URL：休息开始时自动显示遮罩；调试参数 `-showOverlay YES` 立即开始一次休息，`-renderOverlay <路径前缀>` 把遮罩渲染成 PNG
- Viewport：主屏 1728×1117 @2x（内建屏）；副屏 1920×1080 @1x；渲染截图按 1440×900 @2x
- Artifact filename：
  - S4-overlay-short.png：短休息，剩 24 秒（环 0.8、eye 胶囊、喝水按钮、底部跳过）
  - S4-overlay-long.png：长休息，剩 04:12（环 0.84、figure.walk 胶囊）
- Observed result：
  - 截图由 ImageRenderer 在 App 内渲染，用深色实底代替窗口的深色毛玻璃，布局、字号、进度环起点（12 点钟方向）、等宽数字、建议文案位置、喝水按钮和底部跳过按钮均与原型 05、06 一致。
  - 本机终端进程没有屏幕录制权限，`screencapture` 和 `-l<窗口 id>` 只能拿到桌面壁纸（其他 App 的窗口同样不被截入），所以真实毛玻璃效果无法用截图核对，改用 ImageRenderer。
  - 双屏实测（`-fastMode YES`，第 56 秒触发）：`tools/winlist.swift` 显示两块 1728×1117、1920×1080 的窗口，layer=1000（`.screenSaver`）、alpha=1.0；约 12 秒后随休息结束淡出并 `orderOut`。
  - 待用户手动确认：真实毛玻璃观感、Esc 和打字被拦截、跳过按钮、Glass 提示音、焦点归还、其他 App 全屏时仍覆盖、插拔屏幕重建窗口。
