import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var notices = NoticeCenter.shared
    @ObservedObject private var cloud = CloudSync.shared
    @State private var showTimeCost = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Button { showTimeCost = true } label: {
                    SoftPanel(padding: 18) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("1小时时间成本")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(Theme.money(settings.hourlyRate))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.accentDeep)
                                    .monospacedDigit()
                            }
                            Spacer()
                            Text(settings.timeCostAssist.localizedName)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))

                SoftPanel(padding: 4) {
                    VStack(spacing: 0) {
                        menuRow("外观", icon: "circle.lefthalf.filled") {
                            Picker("外观", selection: appearanceBinding) {
                                ForEach(AppearanceMode.allCases) { mode in
                                    Text(mode.localizedName).tag(mode)
                                }
                            }
                        }
                        Divider().padding(.leading, 52)
                        menuRow("语言", icon: "globe") {
                            Picker("语言", selection: languageBinding) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.label).tag(lang)
                                }
                            }
                        }
                    }
                }

                SoftPanel(padding: 4) {
                    VStack(spacing: 0) {
                        Button(action: openNotificationSettings) {
                            settingsRow("通知", icon: "bell", subtitle: notificationSubtitle)
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            BlockListView()
                        } label: {
                            settingsRow("黑名单", icon: "person.crop.circle.badge.xmark")
                        }
                    }
                }

                SoftPanel(padding: 4) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            LegalDocumentView(document: .support)
                        } label: {
                            settingsRow("支持与帮助", icon: "questionmark.circle")
                        }
                        Divider().padding(.leading, 52)
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
                    }
                }

                SoftPanel(padding: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("关于雾中仙")
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

                if cloud.canWrite {
                    SoftPanel(padding: 4) {
                        NavigationLink {
                            DeleteAccountView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.minus")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.warn)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("注销账号")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Theme.warn)
                                    Text("删除账号及云端数据，不可恢复")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AtmosphereBackground())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notices.refreshStatus() }
        .sheet(isPresented: $showTimeCost) {
            NavigationStack { TimeCostSheet() }
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var notificationSubtitle: String {
        switch notices.status {
        case .notDetermined: return L("冷静期结束、收到建议时提醒你")
        case .denied: return L("已关闭，点此去系统设置开启")
        default: return L("已开启")
        }
    }

    private func openNotificationSettings() {
        if notices.status == .notDetermined {
            Task { await notices.requestIfNeeded() }
        } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { settings.language },
            set: { settings.language = $0 }
        )
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { settings.appearance },
            set: { settings.appearance = $0 }
        )
    }

    private func menuRow<Content: View>(
        _ title: LocalizedStringKey,
        icon: String,
        @ViewBuilder picker: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            picker()
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Theme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func settingsRow(
        _ title: LocalizedStringKey,
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

/// 修改 1 小时时间成本
private struct TimeCostSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var hourlyText = ""
    @State private var monthlyText = ""
    @State private var dailyText = ""
    @State private var hoursText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Theme.money(settings.hourlyRate))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accentDeep)
                    .monospacedDigit()

                Picker("估算方式", selection: assistBinding) {
                    ForEach(TimeCostAssist.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch settings.timeCostAssist {
                case .manual:
                    labeledField("直接填写 1 小时值多少钱", text: $hourlyText) { applyHourly() }
                case .monthly:
                    labeledField("每月收入（\(Theme.currencyUnit)）", text: $monthlyText) { applyMonthly() }
                    labeledField("每天大约工作几小时", text: $hoursText) { applyHours() }
                    Stepper("每月大约工作 \(settings.workDaysPerMonth) 天", value: $settings.workDaysPerMonth, in: 8...31)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                case .daily:
                    labeledField("每天收入（\(Theme.currencyUnit)）", text: $dailyText) { applyDaily() }
                    labeledField("每天大约工作几小时", text: $hoursText) { applyHours() }
                }
            }
            .padding(20)
        }
        .background(Theme.paper)
        .navigationTitle("1小时时间成本")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
        .onAppear { syncTexts() }
    }

    private var assistBinding: Binding<TimeCostAssist> {
        Binding(
            get: { settings.timeCostAssist },
            set: { settings.timeCostAssist = $0; syncTexts() }
        )
    }

    private func labeledField(_ title: LocalizedStringKey, text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
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
}
