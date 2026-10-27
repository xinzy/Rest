# S1 · 菜单栏面板（占位）界面验证

- **Changed files**：`project.yml`、`XieHuiEr/Resources/Info.plist`、`XieHuiEr/App/AppDelegate.swift`、
  `XieHuiEr/UI/MenuBar/StatusItemController.swift`、`XieHuiEr/UI/MenuBar/PanelWindow.swift`、
  `XieHuiEr/UI/MenuBar/PanelView.swift`、`XieHuiErTests/PanelPlacementTests.swift`、`tools/winlist.swift`
- **Route or URL**：菜单栏圆环图标 → 面板。截图时用 DEBUG 启动参数 `-openPanel YES` 自动打开；交互由用户在两块屏幕上手动点击验证。
- **Viewport**：内建屏 1728×1117pt（带刘海，菜单栏高 37pt）+ 外接屏 1920×1080pt（1x，菜单栏高 24pt，位于内建屏上方）；系统外观为深色。
  截图时面板在外接屏上，所以是 1x 像素。
- **Artifact filename**：
  - `S1-panel.png`：只截面板窗口（含窗口阴影），366×249px
  - `S1-panel-under-icon.png`：菜单栏图标和面板所在区域，368×261px
- **Observed result**：
  - 面板 320×203pt，圆角毛玻璃，带 0.5pt 描边和阴影。卡片里是静态圆环和眼睛图标，标题「歇会儿」，副标题「计时功能开发中」。
    下方是「报表…」「设置…」两行（暂不可用，显示为灰色）、分隔线、「退出歇会儿 ⌘Q」。
  - 面板水平居中在图标正下方，离菜单栏 6pt；面板打开期间图标呈按下高亮。
    日志核对过两块屏幕：外接屏图标 x=1250 时面板 x=1109，内建屏图标 x=1168 时面板 x=1027，都等于「图标中心 − 160」。
  - 打开面板后前台 App 不变（iTerm、飞书都保持在前台），不出现 Dock 图标（`lsappinfo` 显示 ApplicationType = UIElement）。
  - 用户手动验证通过（2026-10-27）：位置和外观、点别处/Esc/再点图标收起、⌘Q 和「退出歇会儿」退出、全程没有 Dock 图标。
    日志中能看到每种收起方式各自的调用路径；两种退出方式都先收起面板，再调用 `terminate:`。
  - 与原型 02-panel 的差异（都符合预期）：
    - 原型是浅色外观，这里是深色外观。
    - 内容是 S1 的占位，没有剩余时间、立即休息/暂停、喝水这几块（S3、S8 实现）。
    - 圆环是静态满环（S3 实现进度）。
