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

struct MoneyField: View {
    let title: String
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
    let title: String
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

enum AssetIconOption: String, CaseIterable, Identifiable {
    case phone = "iphone"
    case laptop = "laptopcomputer"
    case headphones = "headphones"
    case watch = "applewatch"
    case bag = "bag"
    case tshirt = "tshirt"
    case lipstick = "paintpalette"
    case cream = "drop"
    case book = "book"
    case game = "gamecontroller"
    case cart = "cart"
    case house = "house"
    case car = "car"
    case ticket = "ticket"
    case gift = "gift"
    case cube = "cube"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .phone: return "手机"
        case .laptop: return "电脑"
        case .headphones: return "耳机"
        case .watch: return "手表"
        case .bag: return "包"
        case .tshirt: return "衣物"
        case .lipstick: return "美妆"
        case .cream: return "护肤"
        case .book: return "书籍"
        case .game: return "娱乐"
        case .cart: return "购物"
        case .house: return "家居"
        case .car: return "出行"
        case .ticket: return "票务"
        case .gift: return "礼品"
        case .cube: return "其他"
        }
    }
}

struct IconGridPicker: View {
    @Binding var symbol: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(AssetIconOption.allCases) { option in
                Button {
                    symbol = option.rawValue
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: option.rawValue)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(symbol == option.rawValue ? Color.white : Theme.accent)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(symbol == option.rawValue ? Theme.accent : Theme.accentSoft)
                            )
                        Text(option.label)
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }
}
