# S10 设置

- Changed files：XieHuiEr/System/SettingsStore.swift（新）、XieHuiEr/System/LoginItem.swift（新）、XieHuiEr/UI/Settings/SettingsModel.swift（新）、SettingsView.swift（新）、SettingsComponents.swift（新）、SettingsWindowController.swift（新）、XieHuiEr/App/BreakController.swift、XieHuiEr/UI/MenuBar/StatusItemController.swift、XieHuiEr/App/AppDelegate.swift、XieHuiErTests/SettingsStoreTests.swift（新）、XieHuiErTests/SettingsModelTests.swift（新）
- Route or URL：面板「设置… ⌘,」→ 520×620 独立窗口；调试参数 `-renderSettings <前缀>` 打开真实窗口并逐个标签页截图（不依赖屏幕录制权限）
- Viewport：窗口 520×620，截图 1x，跟随系统外观（本次抓图是深色）
- Artifact filename：
  - S10-settings-general.png（工作时间开关、工作日、时间段；离开与会议；启动登录项）
  - S10-settings-rest.png（短休息、长休息、提醒三组）
  - S10-settings-water.png（每日目标）
  - S10-settings-water-error.png（输入 200 后标红、不保存）
- Observed result：
  - 三个标签页的分组、行分隔、脚注与原型 07 一致；数值行右侧是「输入框 + 步进器 + 单位」，开关为 mini 样式。
  - 原生 `TabView` 在 macOS 26 上把标签栏画在标题栏区域（通用 / 休息 / 喝水，选中项高亮），因此截图连标题栏一起截；内容区只截 `contentView` 时看不到标签栏。
  - 与原型有一处已知差异：系统原生标签栏只显示文字、不显示图标（原型是「图标 + 文字」）。按已确认的「用原生 TabView、不自绘」执行，没有手写标签栏。
  - 截图时窗口必须 makeKey，否则非活动窗口的开关会被画成灰色（看起来像「关闭」）。
  - 报错样式：超范围输入只把输入框描红并在行下方给出「请输入 0–30 之间的数字」，右侧数值仍是上次保存的 8。
- 与原型对比：
  - 一致：分组顺序与文案、行高与分隔线、脚注小字、工作日方块、时间段双步进、mini 开关位置、喝水页单行。
  - 差异：标签栏位置（标题栏而非内容顶部）且无图标；深色外观下文字与原型浅色版本对照。
- 待用户手动确认：面板「设置… ⌘,」打开窗口；改数值后失焦/回车立即生效且当前这一轮从头计时；休息进行中改设置等这次结束再生效；关掉长休息后两行子项变灰；登录项在 ad-hoc 签名下是否注册成功、失败时是否出现黄色提示条。
