import Foundation
import Testing
@testable import XieHuiEr

/// 预告浮窗的文案（原型 04）
struct WarningHUDStatusTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func status(kind: BreakKind, remaining: TimeInterval, settings: BreakSettings = BreakSettings()) -> WarningHUDStatus {
        WarningHUDStatus(kind: kind, settings: settings, now: now, dueAt: now + remaining)
    }

    @Test func shortBreak() {
        let s = status(kind: .short, remaining: 28)

        #expect(s.title == "28 秒后开始短休息")
        #expect(s.subtitle == "休息 30 秒，看看远处")
        #expect(s.symbol == "eye")
        #expect(s.postponeTitle == "推迟 5 分钟")
        #expect(abs(s.ringFraction - 28.0 / 30) < 1e-9)
    }

    @Test func longBreak() {
        let s = status(kind: .long, remaining: 26)

        #expect(s.title == "26 秒后开始长休息")
        #expect(s.subtitle == "休息 5 分钟，起来活动一下")
        #expect(s.symbol == "figure.walk")
    }

    @Test func secondsRoundUp() {
        #expect(status(kind: .short, remaining: 27.2).title == "28 秒后开始短休息")
        #expect(status(kind: .short, remaining: 0.3).title == "1 秒后开始短休息")
    }

    @Test func ringFractionIsClampedAndZeroWithoutLead() {
        #expect(status(kind: .short, remaining: 120).ringFraction == 1)
        #expect(status(kind: .short, remaining: 0).ringFraction == 0)

        var settings = BreakSettings()
        settings.warningLead = 0
        #expect(status(kind: .short, remaining: 10, settings: settings).ringFraction == 0)
    }

    @Test func postponeTitleFollowsSettings() {
        var settings = BreakSettings()
        settings.postponeDuration = 20
        #expect(status(kind: .short, remaining: 5, settings: settings).postponeTitle == "推迟 20 秒")
    }
}

/// 预告浮窗的位置：鼠标所在屏幕的右上角、菜单栏下方
struct WarningHUDPlacementTests {
    private let size = CGSize(width: 330, height: 150)

    @Test func topRightOfMainScreen() {
        let point = WarningHUDPlacement.topLeft(size: size, in: CGRect(x: 0, y: 0, width: 1728, height: 1080))

        #expect(abs(point.x - (1728 - 10 - 330)) < 1e-9)
        #expect(abs(point.y - (1080 - 8 - 150)) < 1e-9)
    }

    @Test func topRightOfScreenLeftOfMain() {
        let point = WarningHUDPlacement.topLeft(size: size, in: CGRect(x: -108, y: -1080, width: 1920, height: 1080))

        #expect(abs(point.x - (-108 + 1920 - 10 - 330)) < 1e-9)
        #expect(abs(point.y - (-1080 + 1080 - 8 - 150)) < 1e-9)
    }

    @Test func staysAtLeftMarginOnNarrowScreen() {
        let point = WarningHUDPlacement.topLeft(size: size, in: CGRect(x: 0, y: 0, width: 320, height: 600))

        #expect(abs(point.x - 10) < 1e-9)
    }
}
