import Foundation

/// 预告浮窗的文案（原型 04），由即将到来的休息算出。纯逻辑，便于测试。
struct WarningHUDStatus: Equatable {
    var title: String
    var subtitle: String
    var symbol: String
    var ringFraction: Double
    var postponeTitle: String

    init(kind: BreakKind, settings: BreakSettings, now: Date, dueAt: Date) {
        let remaining = max(0, dueAt.timeIntervalSince(now))
        let seconds = Int(remaining.rounded(.up))
        title = "\(seconds) 秒后开始\(PanelStatus.kindName(kind))"
        symbol = kind == .long ? "figure.walk" : "eye"
        subtitle = kind == .long
            ? "休息 \(PanelStatus.durationText(settings.longDuration))，起来活动一下"
            : "休息 \(PanelStatus.durationText(settings.shortDuration))，看看远处"
        postponeTitle = "推迟 \(PanelStatus.durationText(settings.postponeDuration))"
        ringFraction = settings.warningLead > 0
            ? min(max(remaining / settings.warningLead, 0), 1)
            : 0
    }
}
