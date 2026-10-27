import AppKit

/// 菜单栏图标的样式（plan.md §3.1，原型 01）
enum RingIconStyle: Equatable {
    /// 工作中：进度环，值为剩余时间的比例，向上取整到 1%，减少重绘
    case progress(Double)
    /// 预告、会议推迟：细圆环 + 中心圆点
    case dot
    /// 休息中：实心圆
    case filled
    /// 暂停：细圆环 + 暂停符号
    case paused
    /// 离开、非工作时间：整个圆环变灰
    case muted

    init(state: BreakState, settings: BreakSettings, now: Date) {
        switch state {
        case .working(let upcoming):
            let percent = (upcoming.dueAt.timeIntervalSince(now) * 100 / settings.shortInterval).rounded(.up)
            self = .progress(min(max(percent, 0), 100) / 100)
        case .warning, .deferred: self = .dot
        case .onBreak: self = .filled
        case .paused: self = .paused
        case .away, .offHours: self = .muted
        }
    }
}

/// 绘制 18×18pt 的模板图（与原型 mockup.js 的 mbIcon 一致）：半径 7pt，进度弧从 12 点方向顺时针
enum RingIcon {
    static func image(_ style: RingIconStyle) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            draw(style)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static let center = NSPoint(x: 9, y: 9)

    private static func draw(_ style: RingIconStyle) {
        switch style {
        case .progress(let fraction):
            strokeRing(width: 2, alpha: 0.28)
            guard fraction > 0 else { return }
            let arc = NSBezierPath()
            // 图像坐标 y 向下：角度递增即视觉上的顺时针，-90° 是 12 点方向
            arc.appendArc(withCenter: center, radius: 7, startAngle: -90, endAngle: -90 + 360 * fraction, clockwise: false)
            arc.lineWidth = 2
            arc.lineCapStyle = .round
            NSColor.black.setStroke()
            arc.stroke()
        case .dot:
            strokeRing(width: 1.5)
            fillCircle(radius: 2.6)
        case .filled:
            fillCircle(radius: 7.75)
        case .paused:
            strokeRing(width: 1.5)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 6.4, y: 6, width: 1.7, height: 6), xRadius: 0.6, yRadius: 0.6).fill()
            NSBezierPath(roundedRect: NSRect(x: 9.9, y: 6, width: 1.7, height: 6), xRadius: 0.6, yRadius: 0.6).fill()
        case .muted:
            strokeRing(width: 2, alpha: 0.35)
        }
    }

    private static func strokeRing(width: CGFloat, alpha: CGFloat = 1) {
        let ring = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 14, height: 14))
        ring.lineWidth = width
        NSColor.black.withAlphaComponent(alpha).setStroke()
        ring.stroke()
    }

    private static func fillCircle(radius: CGFloat) {
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 9 - radius, y: 9 - radius, width: radius * 2, height: radius * 2)).fill()
    }
}
