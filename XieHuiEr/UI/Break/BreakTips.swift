import Foundation

/// 遮罩上的休息建议（plan.md §2.3）：短休息给护眼建议，长休息给活动建议，每次休息随机一条。
enum BreakTips {
    static let short = [
        "看向 6 米外的地方，让眼睛放松一下",
        "闭上眼睛，慢慢转动眼球",
        "多眨几下眼，让眼睛润一润",
        "搓热双手，轻轻敷在闭着的眼睛上",
        "远眺窗外的绿色，放松一下眼睛",
        "把视线从屏幕上移开，看看远处",
        "闭眼休息一会儿，别急着看手机",
    ]

    static let long = [
        "站起来走一走，活动一下肩颈和腰背",
        "做几个深呼吸，伸个懒腰",
        "去接一杯水，顺便活动一下腿脚",
        "转转脖子，耸耸肩，放松肩颈",
        "走到窗边看看远处，让眼睛彻底放松",
        "做几个简单的拉伸，别一直坐着",
        "起来活动一下手腕和脚踝",
    ]

    static func all(for kind: BreakKind) -> [String] {
        kind == .long ? long : short
    }

    static func random(for kind: BreakKind) -> String {
        all(for: kind).randomElement()!
    }
}
