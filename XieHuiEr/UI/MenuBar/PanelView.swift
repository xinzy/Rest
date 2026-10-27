import SwiftUI

/// 面板内容（S1 占位版）：状态区写死；「报表」「设置」暂不可用，只有「退出」可用。尺寸按原型 02。
struct PanelView: View {
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 5)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "eye")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("歇会儿")
                        .font(.system(size: 22, weight: .semibold))
                    Text("计时功能开发中")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .modifier(Platter())

            VStack(spacing: 0) {
                MenuRow(symbol: "chart.bar.xaxis", title: "报表…")
                MenuRow(symbol: "gearshape", title: "设置…", shortcut: "⌘,")
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                MenuRow(symbol: "power", title: "退出歇会儿", shortcut: "⌘Q", action: onQuit)
            }
            .padding(.bottom, 2)
        }
        .padding(10)
        .frame(width: 320)
        .focusEffectDisabled()
    }
}

/// 面板中的分组底板（原型中的 .platter）
private struct Platter: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 11)
        if colorScheme == .dark {
            content
                .background(.white.opacity(0.08), in: shape)
                .overlay { shape.strokeBorder(.white.opacity(0.07), lineWidth: 0.5) }
        } else {
            content
                .background(.white.opacity(0.6), in: shape)
                .shadow(color: .black.opacity(0.1), radius: 0.75, y: 0.5)
        }
    }
}

/// 面板底部类似菜单项的一行；没有 action 时显示为不可用
private struct MenuRow: View {
    let symbol: String
    let title: String
    var shortcut: String?
    var action: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Button {
            action?()
        } label: {
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
            .background(
                isHovered && action != nil ? Color.primary.opacity(0.1) : .clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .onHover { isHovered = $0 }
    }
}
