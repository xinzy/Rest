import SwiftUI

/// 预告浮窗（原型 04）：到点前在鼠标所在屏幕右上角显示，不激活 App、不抢键盘焦点。
struct WarningHUDView: View {
    struct Actions {
        var postpone: () -> Void
        var start: () -> Void
    }

    let controller: BreakController
    let actions: Actions

    var body: some View {
        if case .warning(let upcoming) = controller.scheduler.state {
            WarningHUDContent(
                status: WarningHUDStatus(
                    kind: controller.scheduler.nextKind,
                    settings: controller.scheduler.settings,
                    now: controller.now,
                    dueAt: upcoming.dueAt
                ),
                actions: actions
            )
        }
    }
}

/// 浮窗内容。与控制器解耦，便于用 ImageRenderer 渲染核对（本机没有屏幕录制权限）。
struct WarningHUDContent: View {
    let status: WarningHUDStatus
    let actions: WarningHUDView.Actions

    var body: some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Ring(fraction: status.ringFraction, symbol: status.symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.title)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                    Text(status.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button(status.postponeTitle, action: actions.postpone)
                    .buttonStyle(HUDButtonStyle(primary: false))
                Button("立即开始", action: actions.start)
                    .buttonStyle(HUDButtonStyle(primary: true))
            }
        }
        .padding(14)
        .frame(width: 330)
        .focusEffectDisabled()
    }

    /// 44pt 的进度环，线宽 4pt，从 12 点方向顺时针
    private struct Ring: View {
        let fraction: Double
        let symbol: String

        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(2)
            .frame(width: 44, height: 44)
        }
    }
}

/// 浮窗中的按钮（原型 04）：高 28、圆角 7，主按钮为强调色
private struct HUDButtonStyle: ButtonStyle {
    var primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(primary ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(
                primary ? Color.accentColor : Color.primary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Rectangle())
    }
}
