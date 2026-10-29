import Charts
import Foundation
import SwiftData
import SwiftUI

/// 报表的喝水页（原型 08）：概览卡、每日杯数柱状图和目标线、选中日期的每次喝水记录。
struct WaterReportView: View {
    let model: ReportModel

    /// 鼠标所在的那条记录，悬停时才显示垃圾桶
    @State private var hoveredRecord: PersistentIdentifier?

    private let calendar = Calendar.current

    var body: some View {
        let report = model.waterReport
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                OverviewCard(
                    title: "今日",
                    value: "\(report.todayCount)",
                    unit: report.todayUnit,
                    subtitle: hintText(report),
                    symbol: "drop.fill",
                    symbolColor: .cyan
                )
                OverviewCard(
                    title: "日均",
                    value: report.averageText,
                    unit: "杯",
                    subtitle: report.totalSubtitle
                )
                OverviewCard(
                    title: "达标",
                    value: report.achievedPrimary,
                    unit: report.achievedUnit,
                    subtitle: report.achievedSubtitle
                )
            }
            chartCard(report)
            detailCard
        }
    }

    private func hintText(_ report: WaterReport) -> String {
        WaterStatus(
            count: report.todayCount,
            goal: report.goal,
            lastDrinkAt: model.lastDrinkAt,
            now: Date(),
            calendar: calendar
        ).hintText
    }

    // MARK: - 柱状图

    private func chartCard(_ report: WaterReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ChartHeader(title: "每日杯数") {
                LegendSwatch(color: .cyan, title: "达标")
                LegendSwatch(color: .cyan.opacity(0.42), title: "未达标")
                LegendDash(title: "目标")
            }

            Chart {
                // 今天那一列的浅色底衬
                if let next = calendar.date(byAdding: .day, value: 1, to: model.today) {
                    RectangleMark(
                        xStart: .value("今天开始", model.today),
                        xEnd: .value("今天结束", next),
                        yStart: .value("下限", 0),
                        yEnd: .value("上限", report.chartMax)
                    )
                    .foregroundStyle(Color.primary.opacity(0.05))
                }
                ForEach(report.days, id: \.day) { item in
                    BarMark(
                        x: .value("日期", item.day, unit: .day),
                        y: .value("杯数", item.count),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(barColor(item, goal: report.goal))
                    .cornerRadius(3)
                }
                if report.goal > 0 {
                    RuleMark(y: .value("目标", report.goal))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(Color.cyan.opacity(0.8))
                        .annotation(position: .top, alignment: .trailing, spacing: 2) {
                            Text("目标 \(report.goal) 杯")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.cyan)
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
            .frame(height: 220)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(SpatialTapGesture().onEnded { value in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let x = value.location.x - geometry[plotFrame].origin.x
                            guard let day: Date = proxy.value(atX: x) else { return }
                            model.select(day: day)
                        })
                }
            }
        }
        .padding(14)
        .modifier(ReportCardStyle())
    }

    private func barColor(_ item: WaterDayCount, goal: Int) -> Color {
        guard goal > 0 else { return .cyan }
        return item.count >= goal ? .cyan : .cyan.opacity(0.42)
    }

    private func xDomain(_ days: [WaterDayCount]) -> ClosedRange<Date> {
        let first = days.first?.day ?? model.today
        let last = days.last?.day ?? model.today
        // 柱子按天占满 [当天 0 点, 次日 0 点)，坐标轴要延到次日，否则今天的柱子会被裁掉；
        // 30 天时再多留一天，避免最右边「10-28」的标签被绘图区边缘裁掉
        let extraDays = model.span == .week ? 1 : 2
        let end = calendar.date(byAdding: .day, value: extraDays, to: last) ?? last
        return first...end
    }

    /// 近 7 天每个柱下都标「周几 / 月-日」，今天加粗；近 30 天每隔 5 天标一次
    private func xAxisMarks(_ report: WaterReport) -> some AxisContent {
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

    // MARK: - 当天明细

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                navButton(symbol: "chevron.left", enabled: model.canGoEarlier) {
                    model.shiftDay(by: -1)
                }
                Text(ReportStats.dateText(model.selectedDay, calendar: calendar))
                    .font(.system(size: 13, weight: .bold))
                Text("· \(model.waterRecords.count) 杯")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                navButton(symbol: "chevron.right", enabled: model.canGoLater) {
                    model.shiftDay(by: 1)
                }
                Spacer(minLength: 12)
                Text("在柱状图中点选日期，可查看当天明细")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if model.waterRecords.isEmpty {
                Text("这一天没有记录")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.waterRecords.enumerated()), id: \.element.persistentModelID) { index, record in
                        recordRow(record, number: index + 1)
                    }
                }
            }
        }
        .padding(14)
        .modifier(ReportCardStyle())
    }

    private func navButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func recordRow(_ record: WaterRecord, number: Int) -> some View {
        let isHovered = hoveredRecord == record.persistentModelID
        return HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.system(size: 13))
                .foregroundStyle(.cyan)
            Text(ReportStats.timeText(record.drankAt, calendar: calendar))
                .font(.system(size: 13.5, weight: .semibold))
                .monospacedDigit()
            Text("第 \(number) 杯")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                if hoveredRecord == record.persistentModelID {
                    hoveredRecord = nil
                }
                model.delete(record)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 12.5))
                    if isHovered {
                        Text("删除")
                            .font(.system(size: 12))
                    }
                }
                .foregroundStyle(isHovered ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.secondary))
                .padding(.horizontal, 6)
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .help("删除这条记录")
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(isHovered ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .top) {
            if number > 1 && !isHovered {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 0.5)
            }
        }
        .onHover { inside in
            if inside {
                hoveredRecord = record.persistentModelID
            } else if hoveredRecord == record.persistentModelID {
                hoveredRecord = nil
            }
        }
    }
}
