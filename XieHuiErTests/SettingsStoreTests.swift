import Foundation
import Testing
@testable import XieHuiEr

/// 设置的持久化（plan.md §2.1）：JSON 存在 UserDefaults，字段缺失或整个文件损坏时回退默认值。
@MainActor
struct SettingsStoreTests {
    private let suiteName = "com.shaozeng.xiehuier.tests.settings"

    private func makeStore() -> (SettingsStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (SettingsStore(defaults: defaults), defaults)
    }

    @Test func roundTripKeepsEveryField() {
        let (store, _) = makeStore()
        var settings = BreakSettings()
        settings.shortInterval = 45 * 60
        settings.shortDuration = 20
        settings.longBreakEnabled = false
        settings.longEvery = 6
        settings.longDuration = 4 * 60
        settings.warningLead = 45
        settings.postponeDuration = 10 * 60
        settings.awayThreshold = 8 * 60
        settings.meetingDeferEnabled = false
        settings.soundEnabled = false
        settings.tipsEnabled = false
        settings.workHours = WorkHours(
            enabled: false,
            days: [1, 2, 3],
            startMinutes: 8 * 60 + 30,
            endMinutes: 18 * 60
        )
        settings.waterGoal = 6

        store.save(settings)

        #expect(store.load() == settings)
    }

    @Test func missingKeyReturnsDefaults() {
        let (store, _) = makeStore()
        #expect(store.load() == BreakSettings())
    }

    @Test func corruptDataReturnsDefaults() {
        let (store, defaults) = makeStore()
        defaults.set(Data("不是 JSON".utf8), forKey: SettingsStore.key)
        #expect(store.load() == BreakSettings())
    }

    /// 只存了部分字段时，其余字段用默认值，已存的字段保留
    @Test func partialJSONUsesDefaultsForMissingFields() throws {
        let (store, defaults) = makeStore()
        let json: [String: Any] = [
            "shortInterval": 1200,
            "waterGoal": 6,
            "workHours": ["enabled": false],
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: SettingsStore.key)

        var expected = BreakSettings()
        expected.shortInterval = 1200
        expected.waterGoal = 6
        expected.workHours.enabled = false
        #expect(store.load() == expected)
    }

    @Test func unknownFieldsAreIgnored() throws {
        let (store, defaults) = makeStore()
        var json = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(BreakSettings())
            ) as? [String: Any]
        )
        json["futureSetting"] = 42
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: SettingsStore.key)
        #expect(store.load() == BreakSettings())
    }
}
