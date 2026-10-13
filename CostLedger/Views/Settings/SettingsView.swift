import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var hourlyText = ""
    @State private var monthlyText = ""
    @State private var dailyText = ""
    @State private var hoursText = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                SoftPanel(padding: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1小时时间成本")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)

                        Text(Theme.money(settings.hourlyRate))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accentDeep)
                            .monospacedDigit()

                        Text("用来折算「花了多少分钟」的代价。仅自己可见。")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)

                        Picker("估算方式", selection: assistBinding) {
                            ForEach(TimeCostAssist.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch settings.timeCostAssist {
                        case .manual:
                            labeledField("直接填写 1 小时值多少钱", text: $hourlyText) { applyHourly() }
                        case .monthly:
                            labeledField("每月收入（元）", text: $monthlyText) { applyMonthly() }
                            labeledField("每天大约工作几小时", text: $hoursText) { applyHours() }
                            Stepper("每月大约工作 \(settings.workDaysPerMonth) 天", value: $settings.workDaysPerMonth, in: 8...31)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                            Text("计算：月收入 ÷（工作天数 × 每天小时）")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        case .daily:
                            labeledField("每天收入（元）", text: $dailyText) { applyDaily() }
                            labeledField("每天大约工作几小时", text: $hoursText) { applyHours() }
                            Text("计算：日收入 ÷ 每天小时")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }

                SoftPanel(padding: 4) {
                    Toggle(isOn: $settings.showDailyCost) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("显示今日生活成本相关摘要")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.ink)
                            Text("影响「我的」页统计文案")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 8)
                    }
                    .tint(Theme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }

                SoftPanel(padding: 4) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            LegalDocumentView(document: .privacy)
                        } label: {
                            settingsRow("隐私政策", icon: "hand.raised")
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            LegalDocumentView(document: .terms)
                        } label: {
                            settingsRow("用户协议", icon: "doc.plaintext")
                        }
                        Divider().padding(.leading, 52)
                        settingsRow("订阅会员", icon: "crown", subtitle: "即将上线", showChevron: false)
                    }
                }

                SoftPanel(padding: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("关于代价账本")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("纠结征求建议走决策·待决，小事直接记走决策·已决，别人的纠结在广场，物品在资产。")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                        Text("版本 0.1.0")
                            .font(.caption)
                            .foregroundStyle(Theme.placeholder)
                    }
                }
            }
            .padding(20)
        }
        .background(AtmosphereBackground())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { syncTexts() }
    }

    private var assistBinding: Binding<TimeCostAssist> {
        Binding(
            get: { settings.timeCostAssist },
            set: { settings.timeCostAssist = $0; syncTexts() }
        )
    }

    private func labeledField(_ title: String, text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            TextField(
                "",
                text: text,
                prompt: Text("点此输入").foregroundStyle(Theme.placeholder)
            )
            .keyboardType(.decimalPad)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.ink)
            .fieldBox()
            .onChange(of: text.wrappedValue) { _, new in
                let filtered = DecimalFilter.money(new)
                if filtered != new { text.wrappedValue = filtered }
                onCommit()
            }
        }
    }

    private func syncTexts() {
        hourlyText = settings.hourlyRate > 0 ? String(format: "%g", settings.hourlyRate) : ""
        monthlyText = settings.monthlyIncome > 0 ? String(format: "%g", settings.monthlyIncome) : ""
        dailyText = settings.dailyIncome > 0 ? String(format: "%g", settings.dailyIncome) : ""
        hoursText = settings.hoursPerDay > 0 ? String(format: "%g", settings.hoursPerDay) : "8"
    }

    private func applyHourly() {
        settings.hourlyRate = Double(hourlyText) ?? 0
    }

    private func applyMonthly() {
        settings.monthlyIncome = Double(monthlyText) ?? 0
    }

    private func applyDaily() {
        settings.dailyIncome = Double(dailyText) ?? 0
    }

    private func applyHours() {
        let v = Double(hoursText) ?? 8
        settings.hoursPerDay = max(0.5, v)
    }

    private func settingsRow(
        _ title: String,
        icon: String,
        subtitle: String? = nil,
        showChevron: Bool = true
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}
