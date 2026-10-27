import CoreGraphics
import Testing
@testable import XieHuiEr

/// 面板位置：水平居中在菜单栏图标下方，与菜单栏相隔 6pt，离屏幕可见区域边缘至少 8pt。
struct PanelPlacementTests {
    /// 1440×900 的屏幕，菜单栏高 24pt
    private let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 876)

    @Test func centersUnderStatusItem() {
        let item = CGRect(x: 1000, y: 876, width: 28, height: 24)

        let topLeft = PanelPlacement.topLeft(width: 320, under: item, visibleFrame: visibleFrame)

        #expect(topLeft == CGPoint(x: 854, y: 870))
    }

    @Test func staysInsideRightEdge() {
        let item = CGRect(x: 1390, y: 876, width: 28, height: 24)

        let topLeft = PanelPlacement.topLeft(width: 320, under: item, visibleFrame: visibleFrame)

        #expect(topLeft == CGPoint(x: 1440 - 8 - 320, y: 870))
    }

    @Test func staysInsideLeftEdgeOfScreenLeftOfMainScreen() {
        let leftScreen = CGRect(x: -1920, y: 0, width: 1920, height: 1056)
        let item = CGRect(x: -1910, y: 1056, width: 28, height: 24)

        let topLeft = PanelPlacement.topLeft(width: 320, under: item, visibleFrame: leftScreen)

        #expect(topLeft == CGPoint(x: -1912, y: 1050))
    }
}
