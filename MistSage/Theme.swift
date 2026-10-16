import SwiftUI
import UIKit

enum Theme {
    /// 页面底色
    static let paper = Color.adaptive(
        light: UIColor(red: 0.945, green: 0.957, blue: 0.976, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1)
    )
    /// 弱填充（未选中胶囊、禁用态）
    static let paperDeep = Color.adaptive(
        light: UIColor(red: 0.875, green: 0.910, blue: 0.953, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.19, blue: 0.25, alpha: 1)
    )
    /// 卡片/模块底
    static let surface = Color.adaptive(
        light: .white,
        dark: UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
    )
    static let ink = Color.adaptive(
        light: UIColor(red: 0.08, green: 0.11, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1)
    )
    static let inkSoft = Color.adaptive(
        light: UIColor(red: 0.25, green: 0.30, blue: 0.38, alpha: 1),
        dark: UIColor(red: 0.72, green: 0.76, blue: 0.82, alpha: 1)
    )
    static let muted = Color.adaptive(
        light: UIColor(red: 0.40, green: 0.46, blue: 0.55, alpha: 1),
        dark: UIColor(red: 0.55, green: 0.60, blue: 0.68, alpha: 1)
    )
    static let placeholder = Color.adaptive(
        light: UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1),
        dark: UIColor(red: 0.42, green: 0.46, blue: 0.54, alpha: 1)
    )
    static let line = Color.adaptive(
        light: UIColor(red: 0.82, green: 0.87, blue: 0.93, alpha: 1),
        dark: UIColor(red: 0.22, green: 0.26, blue: 0.32, alpha: 1)
    )

    static let accent = Color.adaptive(
        light: UIColor(red: 0.35, green: 0.58, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 1)
    )
    static let accentDeep = Color.adaptive(
        light: UIColor(red: 0.25, green: 0.48, blue: 0.88, alpha: 1),
        dark: UIColor(red: 0.55, green: 0.72, blue: 1.0, alpha: 1)
    )
    static let accentSoft = Color.adaptive(
        light: UIColor(red: 0.88, green: 0.93, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.24, blue: 0.38, alpha: 1)
    )

    static let moss = accent
    static let mossSoft = accentSoft
    static let warn = Color.adaptive(
        light: UIColor(red: 0.78, green: 0.28, blue: 0.26, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.45, blue: 0.42, alpha: 1)
    )
    static let warnSoft = Color.adaptive(
        light: UIColor(red: 1.0, green: 0.93, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.32, green: 0.14, blue: 0.14, alpha: 1)
    )

    static let displayFont = Font.system(size: 44, weight: .bold, design: .rounded)
    static let pressDuration: Double = 0.14
    static let enterDuration: Double = 0.22

    /// 币种跟地区走（国内人民币，其余美元），与界面语言无关
    static var usesCNY: Bool { AppRegion.current == .cn }

    static var currencyUnit: String { usesCNY ? L("元") : L("美元") }

    /// 不足 1 小时只显示分钟
    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return L("\(m)分") }
        if m == 0 { return L("\(h)小时") }
        return L("\(h)小时\(m)分")
    }

    /// 倒计时：超过 1 天显示「x天x小时」
    static func remaining(minutes: Int) -> String {
        guard minutes >= 24 * 60 else { return duration(minutes: minutes) }
        let d = minutes / (24 * 60), h = minutes % (24 * 60) / 60
        return h == 0 ? L("\(d)天") : L("\(d)天\(h)小时")
    }

    static func money(_ value: Double) -> String {
        String(format: usesCNY ? "¥%.2f" : "$%.2f", value)
    }
}

private extension Color {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct AtmosphereBackground: View {
    var body: some View {
        Theme.paper.ignoresSafeArea()
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.easeOut(duration: Theme.pressDuration), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var filled: Bool = true
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .default).weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(labelColor)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(fillColor)
                )
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!enabled)
    }

    private var fillColor: Color {
        if !enabled { return Theme.paperDeep }
        return filled ? Theme.accent : Theme.surface
    }

    private var labelColor: Color {
        if !enabled { return Theme.muted }
        return filled ? .white : Theme.accentDeep
    }
}

struct SectionLabel: View {
    let title: LocalizedStringKey
    var trailing: LocalizedStringKey? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

struct EmptyHint: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.accent)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.accentSoft))
            Text(title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 48)
    }
}

struct FieldLabel: View {
    let text: LocalizedStringKey
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.inkSoft)
    }
}

struct FieldBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.accent.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: Theme.accent.opacity(0.06), radius: 4, y: 1)
    }
}

extension View {
    func fieldBox() -> some View { modifier(FieldBox()) }
}
