import SwiftUI

/// 设置页里的一个分组：小标题、圆角白底的行组、可选脚注（原型 07）
struct SettingsSection<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 6)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            }

            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// 分组里的一行：左边文字，右边控件；除第一行外都有一条上分隔线
struct SettingsRow<Control: View>: View {
    let title: String
    var first = false
    @ViewBuilder var control: Control

    var body: some View {
        VStack(spacing: 0) {
            if !first {
                Divider()
            }
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 12)
                control
            }
            .frame(minHeight: 38)
        }
    }
}

/// 数值行：文本框加步进器，失焦或回车时提交；错误时输入框标红并在下方提示
struct NumberInputRow: View {
    let title: String
    let unit: String
    let text: String
    let range: ClosedRange<Int>
    let error: String?
    var first = false
    let onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var focused: Bool

    init(
        title: String,
        unit: String,
        text: String,
        range: ClosedRange<Int>,
        error: String?,
        first: Bool = false,
        onCommit: @escaping (String) -> Void
    ) {
        self.title = title
        self.unit = unit
        self.text = text
        self.range = range
        self.error = error
        self.first = first
        self.onCommit = onCommit
        _draft = State(initialValue: text)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !first {
                Divider()
            }
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 12)
                HStack(spacing: 5) {
                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 46)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    error == nil ? Color.primary.opacity(0.15) : Color.red,
                                    lineWidth: error == nil ? 0.5 : 1.5
                                )
                        }
                        .focused($focused)
                        .onSubmit { commit() }

                    Stepper(
                        "",
                        value: Binding(
                            get: { Int(draft) ?? range.lowerBound },
                            set: { newValue in
                                draft = "\(newValue)"
                                commit()
                            }
                        ),
                        in: range
                    )
                    .labelsHidden()
                    .controlSize(.mini)

                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 38)

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 7)
            }
        }
        .onChange(of: text) { _, newValue in draft = newValue }
        .onChange(of: focused) { _, isFocused in
            if !isFocused {
                commit()
            }
        }
    }

    private func commit() {
        onCommit(draft)
    }
}

/// 工作日选择：周一到周日的方块
struct WeekdayChips: View {
    let days: Set<Int>
    let toggle: (Int) -> Void

    private struct Weekday: Identifiable {
        let id: Int
        let name: String
    }

    private let weekdays = [
        Weekday(id: 2, name: "一"),
        Weekday(id: 3, name: "二"),
        Weekday(id: 4, name: "三"),
        Weekday(id: 5, name: "四"),
        Weekday(id: 6, name: "五"),
        Weekday(id: 7, name: "六"),
        Weekday(id: 1, name: "日"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(weekdays) { weekday in
                let selected = days.contains(weekday.id)
                Button {
                    toggle(weekday.id)
                } label: {
                    Text(weekday.name)
                        .font(.system(size: 12))
                        .frame(width: 27, height: 23)
                        .background(
                            selected ? Color.accentColor : Color.primary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(selected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .help("周\(weekday.name)")
            }
        }
    }
}
