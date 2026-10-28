import Observation
import SwiftUI

/// 全屏遮罩的内容（原型 05、06）。每块屏幕各有一份视图，共享同一个 `OverlayModel`。
struct OverlayView: View {
    struct Actions {
        var skip: () -> Void
        var drinkWater: () -> Void
    }

    let controller: BreakController
    let model: OverlayModel
    let water: WaterCenter
    let actions: Actions

    var body: some View {
        let status = OverlayStatus(active: model.active, tip: model.tip, now: controller.now)
        let waterStatus = WaterStatus(
            count: water.todayCount,
            goal: controller.scheduler.settings.waterGoal,
            lastDrinkAt: water.lastDrinkAt,
            now: controller.now,
            calendar: .current,
            undoUntil: nil
        )
        ZStack {
            Color.black.opacity(0.62)
            VStack(spacing: 0) {
                KindPill(text: status.pillText, symbol: status.symbol)
                CountdownRing(fraction: status.ringFraction, text: status.countdownText)
                    .padding(.top, 36)
                if let tip = status.tip {
                    Text(tip)
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 640)
                        .padding(.top, 30)
                }
                WaterButton(
                    recorded: model.waterRecorded,
                    thirsty: waterStatus.isThirsty,
                    recordedText: waterStatus.overlayRecordedText,
                    hint: waterStatus.hintText,
                    action: actions.drinkWater
                )
                .padding(.top, 54)
            }
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()
                Button("跳过休息", action: actions.skip)
                    .buttonStyle(SkipButtonStyle())
                    .padding(.bottom, 72)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

/// 遮罩的共享状态：一次休息对应一个实例，多块屏幕的视图都读它。
@MainActor
@Observable
final class OverlayModel {
    let active: ActiveBreak
    let tip: String?
    private(set) var waterRecorded = false
    @ObservationIgnored var onWaterRecorded: (() -> Void)?

    init(active: ActiveBreak, tip: String?) {
        self.active = active
        self.tip = tip
    }

    /// 每次休息只能记录一次喝水
    func recordWater() {
        guard !waterRecorded else { return }
        waterRecorded = true
        onWaterRecorded?()
    }
}

// MARK: - 元素

/// 类型胶囊：「短休息 · 30 秒」
private struct KindPill: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 17))
            Text(text)
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 16)
        .frame(height: 32)
        .background(Capsule().fill(.white.opacity(0.12)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
    }
}

/// 240pt 的倒计时环，线宽 10pt，从 12 点方向顺时针显示剩余比例
private struct CountdownRing: View {
    let fraction: Double
    let text: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 10)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(text)
                .font(.system(size: 72, weight: .light))
                .monospacedDigit()
                .kerning(-1)
        }
        .frame(width: 240, height: 240)
    }
}

/// 喝水按钮（原型 06）：默认、距上次喝水满 2 小时高亮、本次休息已记录三种状态；
/// 未记录时按钮下方显示「距上次喝水 X」。
private struct WaterButton: View {
    let recorded: Bool
    let thirsty: Bool
    let recordedText: String
    let hint: String
    let action: () -> Void

    var body: some View {
        let highlighted = thirsty && !recorded
        VStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: recorded ? "checkmark" : "drop.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(recorded ? Color.green : (highlighted ? .black.opacity(0.85) : Color.cyan))
                    Text(recorded ? recordedText : "喝了一杯水")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(recorded ? Color.white.opacity(0.92) : (highlighted ? .black.opacity(0.85) : .white))
                }
                .padding(.horizontal, 24)
                .frame(height: 46)
                .background(Capsule().fill(background(highlighted: highlighted)))
                .overlay(
                    Capsule().strokeBorder(
                        recorded ? Color.green.opacity(0.55) : (highlighted ? .clear : .white.opacity(0.3)),
                        lineWidth: 0.5
                    )
                )
                .shadow(color: highlighted ? Color.cyan.opacity(0.38) : .clear, radius: 16, y: 5)
            }
            .buttonStyle(OverlayButtonStyle())
            .disabled(recorded)

            if !recorded {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func background(highlighted: Bool) -> Color {
        if recorded { return Color.green.opacity(0.18) }
        return highlighted ? Color.cyan : Color.white.opacity(0.16)
    }
}

private struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct SkipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.5 : 0.7))
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.white.opacity(0.08) : Color.clear)
            )
    }
}
