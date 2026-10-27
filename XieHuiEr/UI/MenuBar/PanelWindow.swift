import AppKit
import SwiftUI

/// 菜单栏面板的窗口：无边框的圆角毛玻璃。可以接收键盘输入，但不会激活 App，前台 App 的菜单栏保持不变。
final class PanelWindow: NSPanel {
    private static let cornerRadius: CGFloat = 15

    init(rootView: some View) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = Self.roundedMask(radius: Self.cornerRadius)

        let content = NSHostingView(rootView: rootView.overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        })
        content.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            content.topAnchor.constraint(equalTo: background.topAnchor),
            content.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        contentView = background
        setContentSize(content.fittingSize)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 可拉伸的圆角蒙版，毛玻璃和窗口阴影都按它裁成圆角
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// 面板的位置（与原型一致）：水平居中在菜单栏图标下方，与菜单栏相隔 6pt，离屏幕可见区域边缘至少 8pt。
enum PanelPlacement {
    static let gap: CGFloat = 6
    static let margin: CGFloat = 8

    /// 面板左上角在屏幕坐标系（原点在左下）中的位置
    static func topLeft(width: CGFloat, under item: CGRect, visibleFrame: CGRect) -> CGPoint {
        let centered = item.midX - width / 2
        let x = min(max(centered, visibleFrame.minX + margin), visibleFrame.maxX - margin - width)
        return CGPoint(x: x, y: item.minY - gap)
    }
}
