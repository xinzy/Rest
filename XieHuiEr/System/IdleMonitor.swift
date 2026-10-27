import CoreGraphics
import Foundation
import IOKit.pwr_mgt

/// 键鼠无操作时长和防息屏断言（plan.md §3.3）。只读系统状态，不需要任何权限。
enum IdleMonitor {
    /// 距最后一次键鼠输入的秒数
    static func secondsSinceLastInput() -> TimeInterval {
        // kCGAnyInputEventType：任意输入事件
        let anyInput = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}

/// 是否有程序在阻止显示器休眠（例如正在播放视频）。此时即使无操作也算在看屏幕。
enum DisplaySleepAssertions {
    static func isPrevented() -> Bool {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&unmanaged) == kIOReturnSuccess,
              let dictionary = unmanaged?.takeRetainedValue() as? [String: NSNumber] else {
            return false
        }
        return level(of: kIOPMAssertionTypePreventUserIdleDisplaySleep, in: dictionary) > 0
            || level(of: kIOPMAssertionTypeNoDisplaySleep, in: dictionary) > 0
    }

    private static func level(of type: String, in dictionary: [String: NSNumber]) -> Int {
        dictionary[type]?.intValue ?? 0
    }
}
