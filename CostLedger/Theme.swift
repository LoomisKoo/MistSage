import SwiftUI

enum Theme {
    /// 浅蓝色主题：按钮/强调用蓝；模块白底无描边
    static let paper = Color(red: 0.945, green: 0.957, blue: 0.976)      // #F1F4F9
    static let paperDeep = Color(red: 0.875, green: 0.910, blue: 0.953)  // #DFE8F3
    static let surface = Color.white
    static let ink = Color(red: 0.08, green: 0.11, blue: 0.18)           // #141C2E
    static let inkSoft = Color(red: 0.25, green: 0.30, blue: 0.38)        // #404D61
    static let muted = Color(red: 0.40, green: 0.46, blue: 0.55)          // #66758C
    static let placeholder = Color(red: 0.58, green: 0.64, blue: 0.72)
    static let line = Color(red: 0.82, green: 0.87, blue: 0.93)

    /// 主题蓝（按钮、Tab 选中、开关）
    static let accent = Color(red: 0.35, green: 0.58, blue: 0.95)         // #5994F2
    static let accentDeep = Color(red: 0.25, green: 0.48, blue: 0.88)     // #407AE0
    static let accentSoft = Color(red: 0.88, green: 0.93, blue: 1.0)      // #E0EDFF

    static let moss = accent
    static let mossSoft = accentSoft
    static let warn = Color(red: 0.78, green: 0.28, blue: 0.26)
    static let warnSoft = Color(red: 1.0, green: 0.93, blue: 0.92)

    static let displayFont = Font.system(size: 44, weight: .bold, design: .rounded)
    static let pressDuration: Double = 0.14
    static let enterDuration: Double = 0.22

    static func money(_ value: Double) -> String {
        String(format: "¥%.2f", value)
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
    let title: String
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
    let title: String
    var trailing: String? = nil

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
    let title: String
    let message: String

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
    let text: String
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
                    .fill(Color.white)
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
