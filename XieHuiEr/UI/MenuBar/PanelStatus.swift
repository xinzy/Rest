import Foundation

/// 面板状态区要显示的内容（原型 02、03），由调度器的状态算出。纯逻辑，便于测试。
struct PanelStatus: Equatable {
    enum Tint: Equatable {
        case accent, orange, muted
    }

    enum Headline: Equatable {
        /// 倒计时，用等宽数字显示
        case countdown(String)
        case word(String)
    }

    enum SecondTile: Equatable {
        case pause(enabled: Bool, subtitle: String)
        case resume
    }

    var headline: Headline
    var subtitle: String
    /// SF Symbol 名称，显示在进度环中间
    var symbol: String
    var tint: Tint
    var ringFraction: Double
    /// 长休息关闭或非工作时间时为 nil
    var dots: RoundDots?
    var roundsText: String
    var breakNowSubtitle: String
    var breakNowEnabled: Bool
    var secondTile: SecondTile

    init(scheduler: BreakScheduler, now: Date, calendar: Calendar = .current) {
        let settings = scheduler.settings
        let nextKind = scheduler.nextKind
        let round = scheduler.roundsSinceLong + 1
        let longEvery = settings.longEvery
        let roundLabel = settings.longBreakEnabled ? "第 \(round) / \(longEvery) 轮" : nil
        func withRound(_ suffix: String) -> String {
            roundLabel.map { "\($0) · \(suffix)" } ?? suffix
        }

        dots = settings.longBreakEnabled ? RoundDots(total: longEvery, current: round - 1) : nil
        breakNowSubtitle = "\(Self.kindName(nextKind)) · \(Self.durationText(settings.duration(of: nextKind)))"
        breakNowEnabled = true
        secondTile = .pause(enabled: true, subtitle: "选择时长")

        switch scheduler.state {
        case .working(let upcoming), .warning(let upcoming):
            headline = .countdown(Self.countdownText(upcoming.dueAt.timeIntervalSince(now)))
            subtitle = "后开始\(Self.kindName(nextKind))（\(Self.durationText(settings.duration(of: nextKind)))）"
            symbol = nextKind == .long ? "figure.walk" : "eye"
            tint = .accent
            ringFraction = Self.workingFraction(upcoming, settings: settings, now: now)
            if !settings.longBreakEnabled {
                roundsText = "长休息已关闭"
            } else if nextKind == .long {
                roundsText = withRound("长休息")
            } else if round == longEvery - 1 {
                roundsText = withRound("下轮长休息")
            } else {
                roundsText = roundLabel ?? ""
            }

        case .deferred:
            headline = .word("正在开会")
            subtitle = "麦克风或摄像头正在使用"
            symbol = "mic"
            tint = .orange
            ringFraction = 1
            roundsText = "会议结束后先预告，再休息"

        case .onBreak(let active):
            headline = .countdown(Self.countdownText(active.endsAt.timeIntervalSince(now)))
            subtitle = "后结束\(Self.kindName(active.kind))"
            symbol = "cup.and.saucer"
            tint = .accent
            ringFraction = Self.clamped(active.endsAt.timeIntervalSince(now) / active.endsAt.timeIntervalSince(active.startedAt))
            roundsText = roundLabel ?? "长休息已关闭"
            breakNowEnabled = false
            secondTile = .pause(enabled: false, subtitle: "休息中不可用")

        case .paused(let until):
            headline = .word("已暂停")
            subtitle = until.map { "\(ClockText.relative($0, now: now, calendar: calendar)) 自动恢复" } ?? "直到手动恢复"
            symbol = "pause"
            tint = .muted
            ringFraction = 0
            roundsText = withRound("恢复后从头计时")
            secondTile = .resume

        case .offHours(let nextStart):
            headline = .word("非工作时间")
            subtitle = nextStart.map { "\(ClockText.relative($0, now: now, calendar: calendar)) 开始提醒" } ?? "未设置工作日"
            symbol = "moon"
            tint = .muted
            ringFraction = 0
            dots = nil
            roundsText = settings.workHours.days.isEmpty
                ? settings.workHours.summary
                : "工作时间：\(settings.workHours.summary)"
            secondTile = .pause(enabled: false, subtitle: "非工作时间不可用")

        case .away(let since):
            headline = .word("已离开")
            subtitle = "\(ClockText.relative(since, now: now, calendar: calendar)) 起无操作"
            symbol = "zzz"
            tint = .muted
            ringFraction = 0
            roundsText = withRound("回来后从头计时")
            secondTile = .pause(enabled: false, subtitle: "离开时不可用")
        }
    }

    /// 工作中进度环的比例：剩余时间占休息间隔的比例
    static func workingFraction(_ upcoming: UpcomingBreak, settings: BreakSettings, now: Date) -> Double {
        clamped(upcoming.dueAt.timeIntervalSince(now) / settings.shortInterval)
    }

    static func kindName(_ kind: BreakKind) -> String {
        kind == .long ? "长休息" : "短休息"
    }

    /// 时长：「20 秒」「5 分钟」「1 分 30 秒」
    static func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let (minutes, rest) = total.quotientAndRemainder(dividingBy: 60)
        if minutes == 0 { return "\(rest) 秒" }
        if rest == 0 { return "\(minutes) 分钟" }
        return "\(minutes) 分 \(rest) 秒"
    }

    /// 倒计时：不足一小时为「24:13」，否则为「1:05:00」；不足一秒的部分向上取整
    static func countdownText(_ remaining: TimeInterval) -> String {
        let total = Int(max(0, remaining).rounded(.up))
        let (hours, rest) = total.quotientAndRemainder(dividingBy: 3600)
        let (minutes, seconds) = rest.quotientAndRemainder(dividingBy: 60)
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// 状态区的轮次圆点：共 total 个，最后一个代表长休息；current 是当前这一轮的下标
struct RoundDots: Equatable {
    var total: Int
    var current: Int
}

/// 暂停菜单的选项（原型 03 ①）
enum PauseOption: CaseIterable {
    case thirtyMinutes, oneHour, untilTomorrow, untilResumed

    var title: String {
        switch self {
        case .thirtyMinutes: "30 分钟"
        case .oneHour: "1 小时"
        case .untilTomorrow: "直到明天"
        case .untilResumed: "直到手动恢复"
        }
    }

    /// 暂停到什么时候；nil 表示直到手动恢复
    func until(now: Date, calendar: Calendar) -> Date? {
        switch self {
        case .thirtyMinutes: now + 30 * 60
        case .oneHour: now + 60 * 60
        case .untilTomorrow: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        case .untilResumed: nil
        }
    }

    /// 菜单项右侧的说明
    func detail(now: Date, calendar: Calendar) -> String? {
        switch self {
        case .thirtyMinutes, .oneHour:
            until(now: now, calendar: calendar).map { "到 \(ClockText.time($0, calendar: calendar))" }
        case .untilTomorrow: "次日 0 点"
        case .untilResumed: nil
        }
    }
}

/// 时刻的文字形式，不依赖系统的语言和地区设置
enum ClockText {
    private static let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    /// 「09:00」
    static func time(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// 今天：「13:00」；明天：「明天 09:00」；一周以内：「周一 09:00」；更远：「11月10日 09:00」
    static func relative(_ date: Date, now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        let time = time(date, calendar: calendar)
        switch days {
        case 0:
            return time
        case 1:
            return "明天 \(time)"
        case 2..<7:
            return "\(weekdays[calendar.component(.weekday, from: date) - 1]) \(time)"
        default:
            let parts = calendar.dateComponents([.month, .day], from: date)
            return "\(parts.month ?? 0)月\(parts.day ?? 0)日 \(time)"
        }
    }
}
