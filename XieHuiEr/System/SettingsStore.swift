import Foundation

/// 设置的持久化（plan.md §2.1）：整个 BreakSettings 编码成 JSON 存在 UserDefaults。
/// 解码时每个字段独立回退到默认值，以后增删字段不会把旧数据整体作废。
@MainActor
final class SettingsStore {
    /// 测试也需要直接造 JSON，所以不设为 private
    static let key = "breakSettings"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> BreakSettings {
        guard let data = defaults.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(BreakSettings.self, from: data) else {
            return BreakSettings()
        }
        return settings
    }

    func save(_ settings: BreakSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

// MARK: - JSON

extension BreakSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case shortInterval, shortDuration, longBreakEnabled, longEvery, longDuration
        case warningLead, postponeDuration, awayThreshold, meetingDeferEnabled
        case soundEnabled, tipsEnabled, meetingRecheckInterval, workHours, waterGoal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = BreakSettings()
        shortInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .shortInterval) ?? defaults.shortInterval
        shortDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .shortDuration) ?? defaults.shortDuration
        longBreakEnabled = try container.decodeIfPresent(Bool.self, forKey: .longBreakEnabled) ?? defaults.longBreakEnabled
        longEvery = try container.decodeIfPresent(Int.self, forKey: .longEvery) ?? defaults.longEvery
        longDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .longDuration) ?? defaults.longDuration
        warningLead = try container.decodeIfPresent(TimeInterval.self, forKey: .warningLead) ?? defaults.warningLead
        postponeDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .postponeDuration) ?? defaults.postponeDuration
        awayThreshold = try container.decodeIfPresent(TimeInterval.self, forKey: .awayThreshold) ?? defaults.awayThreshold
        meetingDeferEnabled = try container.decodeIfPresent(Bool.self, forKey: .meetingDeferEnabled) ?? defaults.meetingDeferEnabled
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? defaults.soundEnabled
        tipsEnabled = try container.decodeIfPresent(Bool.self, forKey: .tipsEnabled) ?? defaults.tipsEnabled
        meetingRecheckInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .meetingRecheckInterval)
            ?? defaults.meetingRecheckInterval
        workHours = try container.decodeIfPresent(WorkHours.self, forKey: .workHours) ?? defaults.workHours
        waterGoal = try container.decodeIfPresent(Int.self, forKey: .waterGoal) ?? defaults.waterGoal
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shortInterval, forKey: .shortInterval)
        try container.encode(shortDuration, forKey: .shortDuration)
        try container.encode(longBreakEnabled, forKey: .longBreakEnabled)
        try container.encode(longEvery, forKey: .longEvery)
        try container.encode(longDuration, forKey: .longDuration)
        try container.encode(warningLead, forKey: .warningLead)
        try container.encode(postponeDuration, forKey: .postponeDuration)
        try container.encode(awayThreshold, forKey: .awayThreshold)
        try container.encode(meetingDeferEnabled, forKey: .meetingDeferEnabled)
        try container.encode(soundEnabled, forKey: .soundEnabled)
        try container.encode(tipsEnabled, forKey: .tipsEnabled)
        try container.encode(meetingRecheckInterval, forKey: .meetingRecheckInterval)
        try container.encode(workHours, forKey: .workHours)
        try container.encode(waterGoal, forKey: .waterGoal)
    }
}

extension WorkHours: Codable {
    private enum CodingKeys: String, CodingKey {
        case enabled, days, startMinutes, endMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = WorkHours()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
        days = try container.decodeIfPresent(Set<Int>.self, forKey: .days) ?? defaults.days
        startMinutes = try container.decodeIfPresent(Int.self, forKey: .startMinutes) ?? defaults.startMinutes
        endMinutes = try container.decodeIfPresent(Int.self, forKey: .endMinutes) ?? defaults.endMinutes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(days, forKey: .days)
        try container.encode(startMinutes, forKey: .startMinutes)
        try container.encode(endMinutes, forKey: .endMinutes)
    }
}
