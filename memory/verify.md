# 验证约定（完成标准）

## 每个切片的完成标准

1. **构建**：没有 error，也不新增 warning。
2. **测试**：单元测试全部通过；改动了 `Core/` 或 `Data/` 的切片，必须新增或更新相应的测试。
3. **运行**：启动 App 不崩溃，日志中没有意外的 error 或 fault；按切片的验收要点（plan.md §6）实际操作一遍。
4. **界面**：涉及界面的切片要截图，并和原型 `design/mockups/screenshots/` 对比；截图和说明写入 `.agent/visual/`（格式见下文）。
5. **记录**：更新 `memory/progress.md`；用户纠正过的问题追加到 `memory/gotchas.md`。

## 命令（在仓库根目录执行；所有 xcodebuild 命令都要带上 DEVELOPER_DIR）

```bash
# 生成工程
xcodegen generate

# 构建
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project XieHuiEr.xcodeproj -scheme XieHuiEr -configuration Debug \
  -derivedDataPath build -quiet build

# 运行单元测试
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project XieHuiEr.xcodeproj -scheme XieHuiEr \
  -derivedDataPath build -quiet test

# 启动（普通模式 / 快速模式）
open build/Build/Products/Debug/XieHuiEr.app
open build/Build/Products/Debug/XieHuiEr.app --args -fastMode YES

# 退出 App：先查到 PID，再用 kill 结束（不要用 pkill 或 killall）
pgrep -x XieHuiEr
kill <PID>

# 查看日志中的错误
log show --last 5m --style compact --predicate 'process == "XieHuiEr"' | grep -iE "error|fault"

# 截图
screencapture -x .agent/visual/<名称>.png

# 重新生成原型截图（先检查脚本错误和内容是否超出画框，有问题就报错退出、不截图）
design/mockups/capture.sh            # 全部画框
design/mockups/capture.sh 02-panel   # 只截一个画框
```

## DEBUG 快速模式参数（`-fastMode YES`）

| 设置 | 正常默认值 | 快速模式 |
|---|---|---|
| 短休息间隔 | 30 分钟 | 60 秒 |
| 短休息时长 | 30 秒 | 10 秒 |
| 长休息 | 每 4 轮一次，5 分钟 | 每 2 轮一次，20 秒 |
| 预告 | 30 秒 | 5 秒 |
| 推迟 | 5 分钟 | 20 秒 |
| 离开判定 | 5 分钟 | 20 秒 |
| 会议复查间隔 | 60 秒 | 5 秒 |
| 工作时间 | 周一至周五 09:00–19:00 | 忽略（始终视为在工作时间内） |

## 界面验证记录格式

每次界面验证写一份 `.agent/visual/<切片>-<界面>.md`，引用同一目录下刚截取的、非空的 PNG 截图，内容必须包含：

- Changed files：改动了哪些文件
- Route or URL：界面入口，例如「菜单栏图标 → 面板」
- Viewport：屏幕分辨率和缩放比例
- Artifact filename：截图文件名
- Observed result：实际看到的结果，以及和原型的差异

## 端到端验收场景（S10 完成时在快速模式下全部走一遍）

1. 启动后菜单栏出现进度环图标，没有 Dock 图标；面板显示剩余时间和「第 1/2 轮」。
2. 到点前出现预告浮窗，在「文本编辑」里打字不会被打断；点「推迟」后浮窗消失，报表中的推迟次数加 1。
3. 遮罩覆盖所有屏幕和其他 App 的全屏界面；倒计时结束后自动退出并有提示音，焦点回到原来的 App。
4. 在遮罩上点「跳过休息」立即退出；报表中的跳过次数加 1。
5. 第 2 轮是长休息；跳过长休息后，下一轮仍然是长休息。
6. 超过离开判定时间不碰键鼠，再回来时重新开始一轮；锁屏、睡眠后回来也一样。
7. 播放视频且不碰键鼠时，不判定为离开，照常提醒休息。
8. 用「语音备忘录」录音时到点，不出现浮窗和遮罩；停止录音后，在一个复查间隔内出现预告。全程没有权限弹窗。
9. 把工作时间改成不包含当前时刻：图标变灰，面板显示下次开始的时间，不再提醒。
10. 在面板点「+1 杯」，今日杯数加 1；5 秒内点撤销后恢复原值。遮罩上的喝水按钮每次休息只能点一次。
11. 报表中的喝水柱状图、目标线、达标天数、每日明细和删除功能都正常；休息统计与以上操作的结果一致。
12. 设置中超出范围的值会被拒绝；修改间隔后当前这一轮从头计时；开机自启开启后，能在「系统设置 → 通用 → 登录项」中看到。
