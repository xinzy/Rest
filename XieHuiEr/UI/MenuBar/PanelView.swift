import SwiftUI

/// 面板内容（原型 02、03）：状态区、「立即休息」「暂停 ▾ / 恢复计时」、喝水那一行、报表、设置、退出。
struct PanelView: View {
    struct Actions {
        var breakNow: () -> Void
        var pause: (PauseOption) -> Void
        var resume: () -> Void
        var drinkWater: () -> Void
        var undoWater: () -> Void
        var openReport: () -> Void
        var openSettings: () -> Void
        var quit: () -> Void
    }

    let controller: BreakController
    let water: WaterCenter
    let actions: Actions

    var body: some View {
        let status = PanelStatus(scheduler: controller.scheduler, now: controller.now)
        let waterStatus = WaterStatus(
            count: water.todayCount,
            goal: controller.scheduler.settings.waterGoal,
            lastDrinkAt: water.lastDrinkAt,
            now: controller.now,
            calendar: .current,
            undoUntil: water.undoDeadline
        )
        VStack(spacing: 10) {
            StatusSection(status: status)
            HStack(spacing: 10) {
                Tile(symbol: "cup.and.saucer", title: "立即休息", subtitle: status.breakNowSubtitle,
                     highlighted: status.breakNowEnabled && status.secondTile != .resume,
                     action: status.breakNowEnabled ? actions.breakNow : nil)
                secondTile(status.secondTile)
            }
            WaterRow(status: waterStatus, drink: actions.drinkWater, undo: actions.undoWater)

            VStack(spacing: 0) {
                MenuRow(symbol: "chart.bar.xaxis", title: "报表…", action: actions.openReport)
                MenuRow(symbol: "gearshape", title: "设置…", shortcut: "⌘,", action: actions.openSettings)
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                MenuRow(symbol: "power", title: "退出歇会儿", shortcut: "⌘Q", action: actions.quit)
            }
            .padding(.bottom, 2)
        }
        .padding(10)
        .frame(width: 320)
        .focusEffectDisabled()
    }

    @ViewBuilder
    private func secondTile(_ tile: PanelStatus.SecondTile) -> some View {
        switch tile {
        case .resume:
            Tile(symbol: "play.fill", title: "恢复计时", subtitle: "开始新的一轮", highlighted: true, action: actions.resume)
        case .pause(let enabled, let subtitle):
            if enabled {
                Menu {
                    let now = controller.now
                    ForEach(PauseOption.allCases, id: \.self) { option in
                        if option == .untilResumed { Divider() }
                        Button {
                            actions.pause(option)
                        } label: {
                            Text(option.title)
                            if let detail = option.detail(now: now, calendar: .current) {
                                Text(detail)
                            }
                        }
                    }
                } label: {
                    TileLabel(symbol: "pause.fill", title: "暂停", subtitle: subtitle, highlighted: false, showsChevron: true)
                }
                .menuStyle(.button)
                .buttonStyle(TileButtonStyle())
                .menuIndicator(.hidden)
            } else {
                Tile(symbol: "pause.fill", title: "暂停", subtitle: subtitle, highlighted: false, action: nil)
            }
        }
    }
}

// MARK: - 状态区

private struct StatusSection: View {
    let status: PanelStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                StatusRing(fraction: status.ringFraction, color: ringColor, symbol: status.symbol)
                VStack(alignment: .leading, spacing: 2) {
                    switch status.headline {
                    case .countdown(let text):
                        Text(text)
                            .font(.system(size: 30, weight: .semibold))
                            .monospacedDigit()
                            .kerning(-0.4)
                    case .word(let text):
                        Text(text)
                            .font(.system(size: 22, weight: .semibold))
                    }
                    Text(status.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                if let dots = status.dots {
                    RoundDotsView(dots: dots)
                }
                Text(status.roundsText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(Platter())
    }

    private var ringColor: Color {
        switch status.tint {
        case .accent: .accentColor
        case .orange: .orange
        case .muted: .secondary
        }
    }
}

/// 56pt 的进度环，线宽 5pt，从 12 点方向顺时针
private struct StatusRing: View {
    let fraction: Double
    let color: Color
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(2.5)
        .frame(width: 56, height: 56)
    }
}

/// 本组轮次：已完成的实心，当前一轮空心，最后一个长条代表长休息
private struct RoundDotsView: View {
    let dots: RoundDots

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dots.total, id: \.self) { index in
                let shape = Capsule()
                let width: CGFloat = index == dots.total - 1 ? 17 : 8
                Group {
                    if index < dots.current {
                        shape.fill(Color.accentColor)
                    } else if index == dots.current {
                        shape.strokeBorder(Color.accentColor, lineWidth: 2)
                    } else {
                        shape.fill(Color.primary.opacity(0.1))
                    }
                }
                .frame(width: width, height: 8)
            }
        }
    }
}

// MARK: - 按钮

private struct Tile: View {
    let symbol: String
    let title: String
    let subtitle: String
    let highlighted: Bool
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            TileLabel(symbol: symbol, title: title, subtitle: subtitle, highlighted: highlighted, showsChevron: false)
        }
        .buttonStyle(TileButtonStyle())
        .disabled(action == nil)
    }
}

private struct TileLabel: View {
    let symbol: String
    let title: String
    let subtitle: String
    let highlighted: Bool
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(highlighted ? Color.white : Color.primary)
                .frame(width: 30, height: 30)
                .background(highlighted ? Color.accentColor : Color.primary.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

/// 磁贴按钮：底板，按下时加深，不可用时整体变淡
private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TileBody(configuration: configuration)
    }

    private struct TileBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .opacity(isEnabled ? 1 : 0.38)
                .modifier(Platter(pressed: configuration.isPressed))
        }
    }
}

/// 面板中的分组底板（原型中的 .platter）
private struct Platter: ViewModifier {
    var pressed = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 11)
        let pressedTint = Color.primary.opacity(pressed ? 0.06 : 0)
        if colorScheme == .dark {
            content
                .background(.white.opacity(0.08), in: shape)
                .background(pressedTint, in: shape)
                .overlay { shape.strokeBorder(.white.opacity(0.07), lineWidth: 0.5) }
        } else {
            content
                .background(pressedTint, in: shape)
                .background(.white.opacity(0.6), in: shape)
                .shadow(color: .black.opacity(0.1), radius: 0.75, y: 0.5)
        }
    }
}

// MARK: - 喝水

/// 喝水那一行（原型 02、03 ⑥）：今日杯数与目标、+1 杯或撤销、进度条、距上次喝水；
/// 距上次喝水满 2 小时时整行高亮。
private struct WaterRow: View {
    let status: WaterStatus
    let drink: () -> Void
    let undo: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var isAlert: Bool {
        status.isThirsty && !status.canUndo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.cyan)
                countText
                Spacer(minLength: 0)
                button
            }
            bar
                .padding(.top, 9)
                .padding(.bottom, 7)
            Text(status.metaText)
                .font(.system(size: 11.5))
                .foregroundStyle(metaColor)
        }
        .padding(EdgeInsets(top: 11, leading: 12, bottom: 10, trailing: 12))
        .modifier(WaterPlatter(alert: isAlert))
    }

    private var countText: Text {
        let prefix = Text("今日 ").font(.system(size: 13))
        let count = Text("\(status.count)").font(.system(size: 15, weight: .bold))
        let suffix = Text(status.goal > 0 ? " / \(status.goal) 杯" : " 杯").font(.system(size: 13))
        return prefix + count + suffix
    }

    private var bar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(Color.cyan)
                    .frame(width: proxy.size.width * status.barFraction)
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private var button: some View {
        if status.canUndo {
            Button(action: undo) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .semibold))
                    Text("撤销")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 11)
                .frame(height: 24)
                .background(Color.primary.opacity(0.1), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        } else {
            Button(action: drink) {
                Text("+1 杯")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color(white: 0).opacity(0.85) : .white)
                    .padding(.horizontal, 11)
                    .frame(height: 24)
                    .background(Color.cyan, in: Capsule())
                    .shadow(color: Color.cyan.opacity(isAlert ? 0.35 : 0), radius: 3)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var metaColor: Color {
        if status.canUndo { return .green }
        return isAlert ? .cyan : .secondary
    }
}

/// 喝水行的底板；距上次喝水满 2 小时时换成青色底加描边（原型 .p-water.alert）
private struct WaterPlatter: ViewModifier {
    let alert: Bool

    func body(content: Content) -> some View {
        if alert {
            let shape = RoundedRectangle(cornerRadius: 11)
            content
                .background(Color.cyan.opacity(0.16), in: shape)
                .overlay { shape.strokeBorder(Color.cyan.opacity(0.55), lineWidth: 1) }
        } else {
            content.modifier(Platter())
        }
    }
}

/// 面板底部类似菜单项的一行
private struct MenuRow: View {
    let symbol: String
    let title: String
    var shortcut: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 0)
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
