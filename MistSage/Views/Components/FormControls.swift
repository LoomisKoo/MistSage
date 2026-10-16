import SwiftUI
import PhotosUI

enum DecimalFilter {
    /// 只保留数字和一个小数点
    static func money(_ raw: String) -> String {
        var result = ""
        var sawDot = false
        for ch in raw {
            if ch.isNumber {
                result.append(ch)
            } else if ch == ".", !sawDot {
                result.append(ch)
                sawDot = true
            }
        }
        return result
    }
}

/// 首次发帖 / 给建议时补填昵称（广场展示用）
struct NicknameRequiredField: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "你的昵称（广场展示）")
            TextField(
                "",
                text: $text,
                prompt: Text("首次参与需要设置昵称").foregroundStyle(Theme.placeholder)
            )
            .foregroundStyle(Theme.ink)
            .fieldBox()
        }
    }
}

struct MoneyField: View {
    let title: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: title)
            TextField(
                "",
                text: $text,
                prompt: Text("点此输入金额，如 12.5").foregroundStyle(Theme.placeholder)
            )
            .keyboardType(.decimalPad)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.ink)
            .fieldBox()
            .onChange(of: text) { _, new in
                let filtered = DecimalFilter.money(new)
                if filtered != new { text = filtered }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MinutesPickerField: View {
    @Binding var minutes: Int

    private var hours: Binding<Int> {
        Binding(
            get: { minutes / 60 },
            set: { minutes = $0 * 60 + (minutes % 60) }
        )
    }

    private var mins: Binding<Int> {
        Binding(
            get: { minutes % 60 },
            set: { minutes = hours.wrappedValue * 60 + $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "时间")
            HStack(spacing: 0) {
                Picker("小时", selection: hours) {
                    ForEach(0..<13, id: \.self) { h in
                        Text("\(h) 小时").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("分钟", selection: mins) {
                    ForEach(0..<60, id: \.self) { m in
                        Text("\(m) 分").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.paperDeep)
            )
        }
    }
}

struct SheetBottomBar: View {
    let title: LocalizedStringKey
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PrimaryButton(title: title, enabled: enabled, action: action)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(Theme.paper.ignoresSafeArea(edges: .bottom))
    }
}
