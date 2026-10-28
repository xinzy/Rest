import AppKit
import SwiftUI

/// 报表窗口的内容（原型 08、09）：顶部分段，下面是滚动的内容区。
struct ReportView: View {
    @Bindable var model: ReportModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("分段", selection: $model.tab) {
                    Text("喝水").tag(ReportModel.Tab.water)
                    Text("休息").tag(ReportModel.Tab.rest)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 168)

                Spacer(minLength: 0)

                Picker("时间范围", selection: $model.span) {
                    ForEach(ReportModel.Span.allCases) { span in
                        Text(span.title).tag(span)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 196)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)

            Divider()

            ScrollView {
                Group {
                    switch model.tab {
                    case .water:
                        WaterReportView(model: model)
                    case .rest:
                        BreakReportView(model: model)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 通用部件

/// 报表中的白色分组卡片（原型 .card）
struct ReportCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        content
            .background(Color(nsColor: .controlBackgroundColor), in: shape)
            .overlay { shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5) }
    }
}

/// 概览卡：标题、大号数值加单位、一行说明
struct OverviewCard: View {
    let title: String
    let value: String
    var unit = ""
    let subtitle: String
    /// 标题前的圆点（休息页）或图标（喝水页）
    var dotColor: Color?
    var symbol: String?
    var symbolColor: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if let dotColor {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                }
                if let symbol, let symbolColor {
                    Image(systemName: symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(symbolColor)
                }
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .semibold))
                    .kerning(-0.3)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 13, leading: 16, bottom: 14, trailing: 16))
        .modifier(ReportCardStyle())
    }
}

/// 图表标题右边的图例：色块加文字
struct LegendSwatch: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
    }
}

/// 图例中的虚线（目标线）
struct LegendDash: View {
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Rectangle()
                .strokeBorder(Color.cyan, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .frame(width: 16, height: 2)
            Text(title)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
    }
}

/// 图表标题行：左边标题，右边图例
struct ChartHeader<Legend: View>: View {
    let title: String
    @ViewBuilder var legend: Legend

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))
            Spacer(minLength: 12)
            HStack(spacing: 14) {
                legend
            }
        }
    }
}
