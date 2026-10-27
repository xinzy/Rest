// 列出某个进程在屏幕上的窗口和所有显示器的范围，用于核对窗口位置、配合 screencapture -l <id> 截图。
// 坐标是 CG 全局坐标：原点在主屏左上角，y 向下。只读窗口信息，不需要屏幕录制权限。
// 用法：swift tools/winlist.swift <pid>
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]) else {
    print("用法：swift tools/winlist.swift <pid>")
    exit(2)
}

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where window[kCGWindowOwnerPID as String] as? Int32 == pid {
    guard let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
          let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
    let id = window[kCGWindowNumber as String] as? Int ?? -1
    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    let alpha = window[kCGWindowAlpha as String] as? Double ?? -1
    let sharing = window[kCGWindowSharingState as String] as? Int ?? -1
    let memory = window[kCGWindowMemoryUsage as String] as? Int ?? -1
    print("window id=\(id) layer=\(layer) alpha=\(alpha) sharing=\(sharing) memory=\(memory) x=\(bounds.minX) y=\(bounds.minY) w=\(bounds.width) h=\(bounds.height)")
}

var count: UInt32 = 0
CGGetActiveDisplayList(0, nil, &count)
var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
CGGetActiveDisplayList(count, &displays, &count)
for display in displays {
    print("display \(display) main=\(display == CGMainDisplayID()) bounds=\(CGDisplayBounds(display))")
}
