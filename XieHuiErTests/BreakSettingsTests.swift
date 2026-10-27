import Foundation
import Testing
@testable import XieHuiEr

/// 设置项的取值范围（plan.md §4.3）。时长都以秒为单位。
struct BreakSettingsTests {
    @Test(arguments: [
        (BreakSettings.Field.shortInterval, 300.0...7200.0),
        (.shortDuration, 10.0...600.0),
        (.longEvery, 2.0...10.0),
        (.longDuration, 60.0...1800.0),
        (.warningLead, 0.0...60.0),
        (.postponeDuration, 60.0...1800.0),
        (.awayThreshold, 60.0...1800.0),
    ])
    func acceptsBoundsAndRejectsJustOutside(field: BreakSettings.Field, bounds: ClosedRange<Double>) {
        #expect(defaults(with: field, bounds.lowerBound).invalidFields == [])
        #expect(defaults(with: field, bounds.upperBound).invalidFields == [])
        #expect(defaults(with: field, bounds.lowerBound - 1).invalidFields == [field])
        #expect(defaults(with: field, bounds.upperBound + 1).invalidFields == [field])
    }

    /// 预告不能短于推迟，否则推迟后会立刻再次预告
    @Test func warningMustBeShorterThanPostpone() {
        var settings = BreakSettings()
        settings.warningLead = 60
        settings.postponeDuration = 60
        #expect(settings.invalidFields == [.warningLead])

        settings.warningLead = 59
        #expect(settings.invalidFields == [])
    }

    /// 默认设置中只改一项
    private func defaults(with field: BreakSettings.Field, _ value: Double) -> BreakSettings {
        var settings = BreakSettings()
        switch field {
        case .shortInterval: settings.shortInterval = value
        case .shortDuration: settings.shortDuration = value
        case .longEvery: settings.longEvery = Int(value)
        case .longDuration: settings.longDuration = value
        case .warningLead: settings.warningLead = value
        case .postponeDuration: settings.postponeDuration = value
        case .awayThreshold: settings.awayThreshold = value
        }
        return settings
    }
}
