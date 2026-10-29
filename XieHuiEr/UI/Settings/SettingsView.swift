import SwiftUI

/// 设置窗口的内容（原型 07）：原生标签页，三页都是滚动表单。
struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        TabView(selection: $model.tab) {
            GeneralSettingsPage(model: model)
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(SettingsModel.Tab.general)

            RestSettingsPage(model: model)
                .tabItem { Label("休息", systemImage: "eye") }
                .tag(SettingsModel.Tab.rest)

            WaterSettingsPage(model: model)
                .tabItem { Label("喝水", systemImage: "drop") }
                .tag(SettingsModel.Tab.water)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 通用

private struct GeneralSettingsPage: View {
    let model: SettingsModel

    var body: some View {
        SettingsPage {
            SettingsSection(
                title: "工作时间",
                footnote: "非工作时间不提醒，菜单栏图标变灰。不识别节假日和调休，放假时可在面板中暂停。时间段不能跨午夜。"
            ) {
                SettingsRow(title: "只在工作时间提醒", first: true) {
                    Toggle("", isOn: Binding(
                        get: { model.settings.workHours.enabled },
                        set: { model.setWorkHoursEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
                SettingsRow(title: "工作日") {
                    WeekdayChips(days: model.settings.workHours.days) { model.toggleDay($0) }
                }
                SettingsRow(title: "时间段") {
                    TimeRangeControl(model: model)
                }
                if let error = model.workHoursError {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 7)
                }
            }

            SettingsSection(
                title: "离开与会议",
                footnote: "离开、锁屏或睡眠都算已经休息过，回来后重新开始一轮。麦克风或摄像头被占用时视为开会，会议结束后再提醒。"
            ) {
                NumberInputRow(
                    title: "无操作多久算离开",
                    unit: "分钟",
                    text: model.valueText(of: .awayThreshold),
                    range: model.rangeValue(of: .awayThreshold),
                    error: model.error(of: .awayThreshold),
                    first: true
                ) { model.commit(field: .awayThreshold, text: $0) }

                SettingsRow(title: "开会时自动推迟") {
                    Toggle("", isOn: Binding(
                        get: { model.settings.meetingDeferEnabled },
                        set: { model.setMeetingDefer($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }

            SettingsSection(title: "启动") {
                SettingsRow(title: "开机自动启动", first: true) {
                    Toggle("", isOn: Binding(
                        get: { model.loginItemEnabled },
                        set: { model.setLoginItem($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }

            if let note = model.loginItemNote {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(note)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 11.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

/// 工作时间段：两个可输入的时刻，开始必须早于结束
private struct TimeRangeControl: View {
    let model: SettingsModel

    var body: some View {
        HStack(spacing: 4) {
            DatePicker(
                "",
                selection: Binding(get: { model.workStart }, set: { model.setWorkStart($0) }),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.stepperField)
            .frame(width: 88)

            Text("至")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            DatePicker(
                "",
                selection: Binding(get: { model.workEnd }, set: { model.setWorkEnd($0) }),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.stepperField)
            .frame(width: 88)
        }
    }
}

// MARK: - 休息

private struct RestSettingsPage: View {
    let model: SettingsModel

    var body: some View {
        SettingsPage {
            SettingsSection(title: "短休息") {
                NumberInputRow(
                    title: "间隔",
                    unit: "分钟",
                    text: model.valueText(of: .shortInterval),
                    range: model.rangeValue(of: .shortInterval),
                    error: model.error(of: .shortInterval),
                    first: true
                ) { model.commit(field: .shortInterval, text: $0) }

                NumberInputRow(
                    title: "时长",
                    unit: "秒",
                    text: model.valueText(of: .shortDuration),
                    range: model.rangeValue(of: .shortDuration),
                    error: model.error(of: .shortDuration)
                ) { model.commit(field: .shortDuration, text: $0) }
            }

            SettingsSection(
                title: "长休息",
                footnote: "节奏为「短 短 短 长」，按 30 分钟间隔约每 2 小时一次长休息。跳过长休息时，下一轮仍是长休息。"
            ) {
                SettingsRow(title: "启用长休息", first: true) {
                    Toggle("", isOn: Binding(
                        get: { model.settings.longBreakEnabled },
                        set: { model.setLongBreakEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
                Group {
                    NumberInputRow(
                        title: "频率",
                        unit: "轮一次",
                        text: model.valueText(of: .longEvery),
                        range: model.rangeValue(of: .longEvery),
                        error: model.error(of: .longEvery)
                    ) { model.commit(field: .longEvery, text: $0) }

                    NumberInputRow(
                        title: "时长",
                        unit: "分钟",
                        text: model.valueText(of: .longDuration),
                        range: model.rangeValue(of: .longDuration),
                        error: model.error(of: .longDuration)
                    ) { model.commit(field: .longDuration, text: $0) }
                }
                .disabled(!model.settings.longBreakEnabled)
                .opacity(model.settings.longBreakEnabled ? 1 : 0.45)
            }

            SettingsSection(title: "提醒", footnote: "预告设为 0 表示不预告，到点直接开始休息。") {
                NumberInputRow(
                    title: "休息前预告",
                    unit: "秒",
                    text: model.valueText(of: .warningLead),
                    range: model.rangeValue(of: .warningLead),
                    error: model.error(of: .warningLead),
                    first: true
                ) { model.commit(field: .warningLead, text: $0) }

                NumberInputRow(
                    title: "推迟时长",
                    unit: "分钟",
                    text: model.valueText(of: .postponeDuration),
                    range: model.rangeValue(of: .postponeDuration),
                    error: model.error(of: .postponeDuration)
                ) { model.commit(field: .postponeDuration, text: $0) }

                SettingsRow(title: "休息结束提示音") {
                    Toggle("", isOn: Binding(
                        get: { model.settings.soundEnabled },
                        set: { model.setSoundEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }

                SettingsRow(title: "显示休息建议") {
                    Toggle("", isOn: Binding(
                        get: { model.settings.tipsEnabled },
                        set: { model.setTipsEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }
        }
    }
}

// MARK: - 喝水

private struct WaterSettingsPage: View {
    let model: SettingsModel

    var body: some View {
        SettingsPage {
            SettingsSection(
                title: "喝水",
                footnote: "设为 0 表示不设目标。距上次喝水满 2 小时后，面板和遮罩上的喝水按钮会高亮。"
            ) {
                NumberInputRow(
                    title: "每日目标",
                    unit: "杯",
                    text: model.waterGoalText,
                    range: 0...30,
                    error: model.waterGoalError,
                    first: true
                ) { model.commitWaterGoal(text: $0) }
            }
        }
    }
}

// MARK: - 页面骨架

/// 每一页都是可滚动的表单，内容 18pt 分组间距、20pt 边距
private struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                content
            }
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 22, trailing: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
