import Foundation

/// 遮罩上由休息状态算出的内容（原型 05、06）。纯逻辑，便于测试。
struct OverlayStatus: Equatable {
    var kind: BreakKind
    /// 「短休息 · 30 秒」
    var pillText: String
    /// 类型胶囊里的 SF Symbol
    var symbol: String
    var countdownText: String
    /// 休息建议；关闭「显示休息建议」时为 nil
    var tip: String?
    /// 进度环显示的剩余比例
    var ringFraction: Double

    init(active: ActiveBreak, tip: String?, now: Date) {
        kind = active.kind
        let duration = active.endsAt.timeIntervalSince(active.startedAt)
        pillText = "\(PanelStatus.kindName(active.kind)) · \(PanelStatus.durationText(duration))"
        symbol = active.kind == .long ? "figure.walk" : "eye"
        countdownText = PanelStatus.countdownText(active.endsAt.timeIntervalSince(now))
        self.tip = tip
        ringFraction = duration > 0
            ? min(max(active.endsAt.timeIntervalSince(now) / duration, 0), 1)
            : 0
    }
}
