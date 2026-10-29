import Foundation
import Observation

/// 设置窗口的数据（plan.md §4.3）：数值在失焦或回车时校验，通过后立即保存并生效；
/// 开关和星期几改了就生效。校验失败时保留上次保存的值，只在界面上标红。
@MainActor
@Observable
final class SettingsModel {
    enum Tab: Hashable {
        case general
        case rest
        case water
    }

    var tab: Tab = .general

    private(set) var settings: BreakSettings
    /// 数值输入的错误文案，键是设置项
    private(set) var fieldErrors: [BreakSettings.Field: String] = [:]
    private(set) var waterGoalError: String?
    /// 工作时间段的编辑草稿；保存成功后与 settings 一致
    private(set) var workStart: Date
    private(set) var workEnd: Date
    private(set) var workHoursError: String?
    private(set) var loginItemEnabled: Bool
    /// 登录项不能用时的黄色提示
    private(set) var loginItemNote: String?

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let loginItem: LoginItem
    @ObservationIgnored private let onApply: (BreakSettings) -> Void
    @ObservationIgnored private let calendar: Calendar

    init(
        settings: BreakSettings,
        store: SettingsStore,
        loginItem: LoginItem,
        now: Date = Date(),
        calendar: Calendar = .current,
        onApply: @escaping (BreakSettings) -> Void
    ) {
        self.settings = settings
        self.store = store
        self.loginItem = loginItem
        self.calendar = calendar
        self.onApply = onApply
        workStart = Self.date(fromMinutes: settings.workHours.startMinutes, now: now, calendar: calendar)
        workEnd = Self.date(fromMinutes: settings.workHours.endMinutes, now: now, calendar: calendar)
        loginItemEnabled = loginItem.isEnabled
        loginItemNote = Self.loginItemNote(for: loginItem, enabled: loginItem.isEnabled)
    }

    // MARK: - 数值输入

    /// 输入框里显示的值（分钟显示为分钟、秒显示为秒）
    func valueText(of field: BreakSettings.Field) -> String {
        "\(displayValue(of: field))"
    }

    /// 取值范围，单位与输入框一致；步进器也用它
    func rangeValue(of field: BreakSettings.Field) -> ClosedRange<Int> {
        switch field {
        case .shortInterval: 5...120
        case .shortDuration: 10...600
        case .longEvery: 2...10
        case .longDuration: 1...30
        case .warningLead: 0...60
        case .postponeDuration: 1...30
        case .awayThreshold: 1...30
        }
    }

    func unitText(of field: BreakSettings.Field) -> String {
        switch field {
        case .shortInterval, .longDuration, .postponeDuration, .awayThreshold: "分钟"
        case .shortDuration, .warningLead: "秒"
        case .longEvery: "轮"
        }
    }

    func error(of field: BreakSettings.Field) -> String? {
        fieldErrors[field]
    }

    func commit(field: BreakSettings.Field, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Int(trimmed), rangeValue(of: field).contains(value) else {
            fieldErrors[field] = rangeMessage(of: field)
            return
        }
        var candidate = settings
        switch field {
        case .shortInterval: candidate.shortInterval = TimeInterval(value * 60)
        case .shortDuration: candidate.shortDuration = TimeInterval(value)
        case .longEvery: candidate.longEvery = value
        case .longDuration: candidate.longDuration = TimeInterval(value * 60)
        case .warningLead: candidate.warningLead = TimeInterval(value)
        case .postponeDuration: candidate.postponeDuration = TimeInterval(value * 60)
        case .awayThreshold: candidate.awayThreshold = TimeInterval(value * 60)
        }
        let invalid = candidate.invalidFields
        guard invalid.isEmpty else {
            fieldErrors = Dictionary(uniqueKeysWithValues: invalid.map { ($0, message(for: $0)) })
            return
        }
        fieldErrors = [:]
        apply(candidate)
    }

    // MARK: - 喝水目标

    var waterGoalText: String {
        "\(settings.waterGoal)"
    }

    func commitWaterGoal(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Int(trimmed), (0...30).contains(value) else {
            waterGoalError = "请输入 0–30 之间的数字"
            return
        }
        waterGoalError = nil
        var candidate = settings
        candidate.waterGoal = value
        apply(candidate)
    }

    // MARK: - 开关

    func setWorkHoursEnabled(_ enabled: Bool) {
        var candidate = settings
        candidate.workHours.enabled = enabled
        apply(candidate)
    }

    func setMeetingDefer(_ enabled: Bool) {
        var candidate = settings
        candidate.meetingDeferEnabled = enabled
        apply(candidate)
    }

    func setLongBreakEnabled(_ enabled: Bool) {
        var candidate = settings
        candidate.longBreakEnabled = enabled
        apply(candidate)
    }

    func setSoundEnabled(_ enabled: Bool) {
        var candidate = settings
        candidate.soundEnabled = enabled
        apply(candidate)
    }

    func setTipsEnabled(_ enabled: Bool) {
        var candidate = settings
        candidate.tipsEnabled = enabled
        apply(candidate)
    }

    // MARK: - 工作时间

    func toggleDay(_ weekday: Int) {
        var candidate = settings
        if candidate.workHours.days.contains(weekday) {
            candidate.workHours.days.remove(weekday)
        } else {
            candidate.workHours.days.insert(weekday)
        }
        apply(candidate)
    }

    func setWorkStart(_ date: Date) {
        workStart = date
        commitWorkHours()
    }

    func setWorkEnd(_ date: Date) {
        workEnd = date
        commitWorkHours()
    }

    private func commitWorkHours() {
        let start = minutes(of: workStart)
        let end = minutes(of: workEnd)
        guard start < end else {
            workHoursError = "开始时间要早于结束时间"
            return
        }
        workHoursError = nil
        var candidate = settings
        candidate.workHours.startMinutes = start
        candidate.workHours.endMinutes = end
        apply(candidate)
    }

    // MARK: - 登录项

    func setLoginItem(_ enabled: Bool) {
        do {
            try loginItem.setEnabled(enabled)
            loginItemEnabled = loginItem.isEnabled
            loginItemNote = Self.loginItemNote(for: loginItem, enabled: loginItemEnabled)
        } catch {
            loginItemEnabled = loginItem.isEnabled
            loginItemNote = "当前为开发构建，可能无法注册登录项；可在系统设置 → 通用 → 登录项中手动添加"
        }
    }

    /// 打开窗口时重新读取系统里的登录项状态
    func refreshLoginItem() {
        loginItemEnabled = loginItem.isEnabled
        loginItemNote = Self.loginItemNote(for: loginItem, enabled: loginItemEnabled)
    }

    // MARK: - 私有

    private func apply(_ newSettings: BreakSettings) {
        settings = newSettings
        store.save(newSettings)
        onApply(newSettings)
    }

    private func displayValue(of field: BreakSettings.Field) -> Int {
        switch field {
        case .shortInterval: Int(settings.shortInterval) / 60
        case .shortDuration: Int(settings.shortDuration)
        case .longEvery: settings.longEvery
        case .longDuration: Int(settings.longDuration) / 60
        case .warningLead: Int(settings.warningLead)
        case .postponeDuration: Int(settings.postponeDuration) / 60
        case .awayThreshold: Int(settings.awayThreshold) / 60
        }
    }

    private func rangeMessage(of field: BreakSettings.Field) -> String {
        let range = rangeValue(of: field)
        return "请输入 \(range.lowerBound)–\(range.upperBound) 之间的数字"
    }

    private func message(for field: BreakSettings.Field) -> String {
        field == .warningLead ? "预告要短于推迟时长" : rangeMessage(of: field)
    }

    private func minutes(of date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func date(fromMinutes minutes: Int, now: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: now) ?? now
    }

    private static func loginItemNote(for loginItem: LoginItem, enabled: Bool) -> String? {
        guard enabled, loginItem.requiresApproval else { return nil }
        return "已注册，需要在系统设置 → 通用 → 登录项中允许"
    }
}
