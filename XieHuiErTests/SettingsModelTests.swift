import Foundation
import Testing
@testable import XieHuiEr

/// 设置窗口的校验与即时生效（plan.md §4.3）：非法输入保留上一次保存的值。
@MainActor
struct SettingsModelTests {
    private let suiteName = "com.shaozeng.xiehuier.tests.settings.model"
    private let calendar = TestCalendar.shanghai

    private func makeModel(
        settings: BreakSettings = BreakSettings(),
        onApply: @escaping (BreakSettings) -> Void = { _ in }
    ) -> SettingsModel {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SettingsModel(
            settings: settings,
            store: SettingsStore(defaults: defaults),
            loginItem: LoginItem(),
            now: TestCalendar.date(2026, 10, 27, 12, 0),
            calendar: calendar,
            onApply: onApply
        )
    }

    @Test func validNumberAppliesImmediately() {
        var applied: BreakSettings?
        let model = makeModel { applied = $0 }

        model.commit(field: .shortInterval, text: "45")

        #expect(model.settings.shortInterval == 45 * 60)
        #expect(applied != nil)
        #expect(applied?.shortInterval == TimeInterval(45 * 60))
        #expect(model.error(of: .shortInterval) == nil)
    }

    @Test func outOfRangeNumberKeepsPreviousValue() {
        var applied = false
        let model = makeModel { _ in applied = true }

        model.commit(field: .shortInterval, text: "4")

        #expect(model.settings.shortInterval == 30 * 60)
        #expect(model.error(of: .shortInterval) == "请输入 5–120 之间的数字")
        #expect(applied == false)
    }

    @Test func nonNumberIsRejected() {
        let model = makeModel()
        model.commit(field: .shortDuration, text: "三十")
        #expect(model.settings.shortDuration == 30)
        #expect(model.error(of: .shortDuration) != nil)
    }

    /// 把推迟时长改到不短于预告时，标出「休息前预告」而不是推迟这一项
    @Test func warningMustBeShorterThanPostpone() {
        var settings = BreakSettings()
        settings.warningLead = 60
        let model = makeModel(settings: settings)

        model.commit(field: .postponeDuration, text: "1")

        #expect(model.settings.postponeDuration == 5 * 60)
        #expect(model.error(of: .warningLead) == "预告要短于推迟时长")
        #expect(model.error(of: .postponeDuration) == nil)
    }

    @Test func waterGoalAcceptsBounds() {
        let model = makeModel()
        model.commitWaterGoal(text: "0")
        #expect(model.settings.waterGoal == 0)
        #expect(model.waterGoalError == nil)

        model.commitWaterGoal(text: "30")
        #expect(model.settings.waterGoal == 30)

        model.commitWaterGoal(text: "31")
        #expect(model.settings.waterGoal == 30)
        #expect(model.waterGoalError == "请输入 0–30 之间的数字")
    }

    @Test func workStartMustBeEarlierThanEnd() {
        var applied = false
        let model = makeModel { _ in applied = true }

        model.setWorkStart(TestCalendar.date(2026, 10, 27, 20, 0))

        #expect(model.workStart == TestCalendar.date(2026, 10, 27, 20, 0))
        #expect(model.settings.workHours.startMinutes == 9 * 60)
        #expect(model.workHoursError == "开始时间要早于结束时间")
        #expect(applied == false)
    }

    @Test func validWorkHoursAreSaved() {
        let model = makeModel()

        model.setWorkStart(TestCalendar.date(2026, 10, 27, 8, 30))
        model.setWorkEnd(TestCalendar.date(2026, 10, 27, 18, 0))

        #expect(model.settings.workHours.startMinutes == 8 * 60 + 30)
        #expect(model.settings.workHours.endMinutes == 18 * 60)
        #expect(model.workHoursError == nil)
    }

    @Test func togglingWeekdayAppliesImmediately() {
        let model = makeModel()
        model.toggleDay(1)

        #expect(model.settings.workHours.days.contains(1))

        model.toggleDay(1)
        #expect(!model.settings.workHours.days.contains(1))
    }
}
