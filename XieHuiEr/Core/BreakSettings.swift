import Foundation

/// 休息相关的设置。时长都以秒为单位，取值范围见 plan.md §4.3。
struct BreakSettings: Equatable, Sendable {
    var shortInterval: TimeInterval = 30 * 60
    var shortDuration: TimeInterval = 30
    var longBreakEnabled = true
    /// 每 N 轮一次长休息
    var longEvery = 4
    var longDuration: TimeInterval = 5 * 60
    /// 休息前预告的秒数，0 表示不预告
    var warningLead: TimeInterval = 30
    var postponeDuration: TimeInterval = 5 * 60
    /// 键鼠无操作多久算离开
    var awayThreshold: TimeInterval = 5 * 60
    var meetingDeferEnabled = true
    /// 开会推迟后多久复查一次，不在设置界面中提供
    var meetingRecheckInterval: TimeInterval = 60

    func duration(of kind: BreakKind) -> TimeInterval {
        kind == .long ? longDuration : shortDuration
    }

    /// DEBUG 快速模式（`-fastMode YES`）：时长都换成秒级，不受取值范围限制
    static let fastMode = BreakSettings(
        shortInterval: 60,
        shortDuration: 10,
        longEvery: 2,
        longDuration: 20,
        warningLead: 5,
        postponeDuration: 20,
        awayThreshold: 20,
        meetingRecheckInterval: 5
    )

    /// 设置界面中可以输入数值的项
    enum Field: CaseIterable, Sendable {
        case shortInterval, shortDuration, longEvery, longDuration, warningLead, postponeDuration, awayThreshold

        var range: ClosedRange<Double> {
            switch self {
            case .shortInterval: 5 * 60...120 * 60
            case .shortDuration: 10...600
            case .longEvery: 2...10
            case .longDuration: 1 * 60...30 * 60
            case .warningLead: 0...60
            case .postponeDuration: 1 * 60...30 * 60
            case .awayThreshold: 1 * 60...30 * 60
            }
        }
    }

    func value(of field: Field) -> Double {
        switch field {
        case .shortInterval: shortInterval
        case .shortDuration: shortDuration
        case .longEvery: Double(longEvery)
        case .longDuration: longDuration
        case .warningLead: warningLead
        case .postponeDuration: postponeDuration
        case .awayThreshold: awayThreshold
        }
    }

    /// 超出取值范围的项；为空时才能保存。
    /// 预告不短于推迟时长时标记预告这一项，否则推迟后会立刻再次预告。
    var invalidFields: [Field] {
        Field.allCases.filter { field in
            if field == .warningLead, warningLead >= postponeDuration { return true }
            return !field.range.contains(value(of: field))
        }
    }
}
