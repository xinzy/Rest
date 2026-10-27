# 参与者与工具

## 参与者
- 主执行者：GitHub Copilot CLI（Claude Opus 5.5）
- 可用的 MCP：github-mcp-server、feishu-mcp（本项目暂时用不到）

## 技术栈
- Swift 6：AppKit 负责外壳（状态栏、窗口），SwiftUI 负责界面内容
- SwiftData 存储记录，UserDefaults 存储设置，Swift Charts 绘制报表
- ServiceManagement（登录项）、CoreGraphics/IOKit（无操作时长、防息屏断言）、CoreAudio/CoreMediaIO（开会检测）
- 不使用第三方依赖

## 本机环境（2026-10-27 检查）
- macOS 15.7.5（24G624），Apple Silicon（arm64）
- Xcode 26.3（17C529），位于 /Applications/Xcode.app，SDK 为 macOS 26.2
- ⚠️ xcode-select 当前指向 /Library/Developer/CommandLineTools。所有 xcodebuild、xcrun 命令都必须带上
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`（不要修改全局设置，也不需要 sudo）
- ⚠️ Command Line Tools（Swift 6.1.2）里没有 SwiftData 的宏插件，不能只用 SwiftPM 加 Command Line Tools 来构建
- XcodeGen：/opt/homebrew/bin/xcodegen；Homebrew：/opt/homebrew/bin/brew
- Google Chrome：/Applications/Google Chrome.app（用无头模式给原型截图）
  - `--headless=new --force-device-scale-factor=2 --window-size=W,H --screenshot` 得到的 PNG 正好是 2W×2H
  - 加了 `--disable-gpu` 时 backdrop-filter 毛玻璃仍然有效；苹果标志（U+F8FF）和苹方字体都能正常显示
- ⚠️ 系统自带的 bash 是 3.2：变量后面紧跟全角字符时（如 `$id（`）会被当成变量名的一部分，必须写成 `${id}`
- 代码仓库：2026-10-27 经用户同意执行了 git init（main 分支，仅本地，没有远程仓库）
- 终端是 iTerm2，没有「辅助功能」和「屏幕录制」权限（2026-10-27 用 AXIsProcessTrusted / CGPreflightScreenCaptureAccess 检查）：
  不能模拟点击和按键；不要直接运行 screencapture（会弹出授权请求）。
  可以不经授权读取窗口的位置、层级和所属进程（CGWindowListCopyWindowInfo，读不到窗口标题）
