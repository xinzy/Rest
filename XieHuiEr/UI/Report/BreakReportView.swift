import Charts
import SwiftUI

/// 报表的休息页（原型 09）：完成/跳过/完成率/推迟四张卡、完成与跳过的堆叠柱状图、每日明细表。
struct BreakReportView: View {
    let model: ReportModel

    private let calendar = Calendar.current
    /// 数字列的宽度（完成、跳过、推迟、开会自动推迟、完成率）
    private let columnWidths: [CGFloat] = [64, 64, 64, 108, 64]

    var body: some View {
        let report = model.breakReport
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                OverviewCard(
                    title: "完成",
                    value: "\(report.completed)",
                    unit: "次",
                    subtitle: report.spanSubtitle,
                    dotColor: .green
                )
                OverviewCard(
                    title: "跳过",
                    value: "\(report.skipped)",
                    unit: "次",
                    subtitle: report.spanSubtitle,
                    dotColor: .orange
                )
                OverviewCard(
                    title: "完成率",
                    value: report.rateNumberText,
                    unit: report.rateUnit,
                    subtitle: "完成 ÷（完成 + 跳过）"
                )
                OverviewCard(
                    title: "推迟",
                    value: "\(report.postponed)",
                    unit: "次",
                    subtitle: report.postponedSubtitle
                )
            }
            chartCard(report)
            tableCard(report)
        }
    }

    // MARK: - 堆叠柱状图

    private func chartCard(_ report: BreakReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ChartHeader(title: "每日休息次数") {
                LegendSwatch(color: .green, title: "完成")
                LegendSwatch(color: .orange, title: "跳过")
            }

            Chart {
                ForEach(report.days, id: \.day) { item in
                    BarMark(
                        x: .value("日期", item.day, unit: .day),
                        y: .value("次数", item.completed),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(Color.green)
                    .cornerRadius(3)

                    BarMark(
                        x: .value("日期", item.day, unit: .day),
                        y: .value("次数", item.skipped),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(Color.orange)
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 2) {
                        if item.total > 0 {
                            Text("\(item.total)")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXScale(domain: xDomain(report.days))
            .chartYScale(domain: 0...report.chartMax)
            .chartXAxis { xAxisMarks(report) }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel()
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
        }
        .padding(14)
        .modifier(ReportCardStyle())
    }

    private func xDomain(_ days: [BreakDaySummary]) -> ClosedRange<Date> {
        let first = days.first?.day ?? model.today
        let last = days.last?.day ?? model.today
        // 柱子按天占满 [当天 0 点, 次日 0 点)，坐标轴要延到次日，否则今天的柱子会被裁掉；
        // 30 天时再多留一天，避免最右边「10-28」的标签被绘图区边缘裁掉
        let extraDays = model.span == .week ? 1 : 2
        let end = calendar.date(byAdding: .day, value: extraDays, to: last) ?? last
        return first...end
    }

    private func xAxisMarks(_ report: BreakReport) -> some AxisContent {
        let days = report.days.map(\.day)
        let values: [Date]
        if model.span == .week {
            values = days
        } else {
            values = days.enumerated().compactMap { index, day in
                (days.count - 1 - index) % 5 == 0 ? day : nil
            }
        }
        return AxisMarks(values: values) { value in
            AxisValueLabel {
                if let day = value.as(Date.self) {
                    VStack(spacing: 1) {
                        Text(ReportStats.weekdayText(day, calendar: calendar))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                        Text(ReportStats.monthDayText(day, calendar: calendar))
                            .font(.system(size: 10, weight: day == model.today ? .bold : .regular))
                            .foregroundStyle(day == model.today ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    }
                }
            }
        }
    }

    // MARK: - 每日明细

    private func tableCard(_ report: BreakReport) -> some View {
        let rows = report.newestFirst
        return VStack(alignment: .leading, spacing: 4) {
            Text("每日明细")
                .font(.system(size: 13, weight: .bold))
            headerRow
            ForEach(Array(rows.enumerated()), id: \.element.day) { index, summary in
                row(summary, isLast: index == rows.count - 1)
            }
        }
        .padding(14)
        .modifier(ReportCardStyle())
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("日期")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("完成").frame(width: columnWidths[0])
            Text("跳过").frame(width: columnWidths[1])
            Text("推迟").frame(width: columnWidths[2])
            Text("开会自动推迟").frame(width: columnWidths[3])
            Text("完成率").frame(width: columnWidths[4])
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 0.5)
        }
    }

    private func row(_ summary: BreakDaySummary, isLast: Bool) -> some View {
        let isToday = summary.day == model.today
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(ReportStats.dateText(summary.day, calendar: calendar))
                if isToday {
                    Text("今天")
                        .font(.system(size: 10.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(summary.completed)").frame(width: columnWidths[0])
            Text("\(summary.skipped)").frame(width: columnWidths[1])
            Text("\(summary.postponed)").frame(width: columnWidths[2])
            Text("\(summary.autoDeferred)").frame(width: columnWidths[3])
            Text(summary.rateText).frame(width: columnWidths[4])
        }
        .font(.system(size: 12.5))
        .monospacedDigit()
        .foregroundStyle(summary.isOff ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
        .padding(.horizontal, 10)
        .frame(height: 29)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 0.5)
            }
        }
    }
}
