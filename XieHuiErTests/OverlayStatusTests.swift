import Foundation
import Testing
@testable import XieHuiEr

/// 遮罩上的文案与进度（原型 05、06）。时间固定在 2026-10-27（周二）10:24:00。
struct OverlayStatusTests {
    private let t0 = TestCalendar.date(2026, 10, 27, 10, 24)

    private func breakOf(_ kind: BreakKind, duration: TimeInterval) -> ActiveBreak {
        ActiveBreak(kind: kind, trigger: .scheduled, startedAt: t0, endsAt: t0 + duration)
    }

    @Test func shortBreakShowsPillCountdownAndEyeIcon() {
        let status = OverlayStatus(
            active: breakOf(.short, duration: 30),
            tip: "看向 6 米外的地方，让眼睛放松一下",
            now: t0 + 6
        )

        #expect(status.kind == .short)
        #expect(status.pillText == "短休息 · 30 秒")
        #expect(status.symbol == "eye")
        #expect(status.countdownText == "00:24")
        #expect(status.tip == "看向 6 米外的地方，让眼睛放松一下")
        #expect(abs(status.ringFraction - 0.8) < 1e-9)
    }

    @Test func longBreakShowsPillCountdownAndWalkIcon() {
        let status = OverlayStatus(
            active: breakOf(.long, duration: 5 * 60),
            tip: nil,
            now: t0 + 48
        )

        #expect(status.kind == .long)
        #expect(status.pillText == "长休息 · 5 分钟")
        #expect(status.symbol == "figure.walk")
        #expect(status.countdownText == "04:12")
        #expect(status.tip == nil)
        #expect(abs(status.ringFraction - 252.0 / 300) < 1e-9)
    }

    @Test func ringFractionIsClampedAndCountdownStopsAtZero() {
        let active = breakOf(.short, duration: 30)

        let afterEnd = OverlayStatus(active: active, tip: nil, now: t0 + 31)
        #expect(afterEnd.countdownText == "00:00")
        #expect(afterEnd.ringFraction == 0)

        let beforeStart = OverlayStatus(active: active, tip: nil, now: t0 - 10)
        #expect(beforeStart.ringFraction == 1)
    }
}

struct BreakTipsTests {
    @Test func poolsAreNonEmptyAndUnique() {
        #expect(!BreakTips.short.isEmpty)
        #expect(!BreakTips.long.isEmpty)
        #expect(Set(BreakTips.short).count == BreakTips.short.count)
        #expect(Set(BreakTips.long).count == BreakTips.long.count)
        #expect(BreakTips.short != BreakTips.long)
    }

    @Test func randomTipComesFromTheMatchingPool() {
        for _ in 0..<20 {
            #expect(BreakTips.short.contains(BreakTips.random(for: .short)))
            #expect(BreakTips.long.contains(BreakTips.random(for: .long)))
        }
    }
}

@MainActor
struct OverlayModelTests {
    @Test func waterCanOnlyBeRecordedOncePerBreak() {
        let t0 = TestCalendar.date(2026, 10, 27, 10, 24)
        let model = OverlayModel(
            active: ActiveBreak(kind: .short, trigger: .scheduled, startedAt: t0, endsAt: t0 + 30),
            tip: nil
        )
        var recorded = 0
        model.onWaterRecorded = { recorded += 1 }

        #expect(!model.waterRecorded)
        model.recordWater()
        model.recordWater()

        #expect(model.waterRecorded)
        #expect(recorded == 1)
    }
}

@MainActor
struct BreakControllerTests {
    @Test func reportsBreakStartAndSkip() {
        let controller = BreakController(settings: BreakSettings())
        var started: ActiveBreak?
        var ended: BreakRecord?
        controller.onBreakStarted = { started = $0 }
        controller.onBreakEnded = { ended = $0 }

        controller.breakNow()
        #expect(started?.kind == .short)
        #expect(controller.scheduler.state.isOnBreak)

        controller.skipBreak()
        #expect(ended?.outcome == .skipped)
        #expect(ended?.kind == .short)
        #expect(!controller.scheduler.state.isOnBreak)
    }
}
