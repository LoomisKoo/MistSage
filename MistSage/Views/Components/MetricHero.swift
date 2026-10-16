import SwiftUI

struct MetricHero: View {
    let eyebrow: LocalizedStringKey
    let value: String
    /// 已解析的文案（静态用 L()，含插值时同样）
    let footnote: String
    var accent: Color = Theme.ink
    var softFill: Color = Theme.surface

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(Theme.muted)

            Text(value)
                .font(Theme.displayFont)
                .foregroundStyle(accent)
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(softFill)
        )
    }
}

struct SoftPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
            )
    }
}

/// 类型 / 状态这类小标签：圆角矩形底色
struct MetaTag: View {
    let text: String
    var fg: Color = Theme.inkSoft
    var bg: Color = Theme.paperDeep

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(bg)
            )
    }
}
