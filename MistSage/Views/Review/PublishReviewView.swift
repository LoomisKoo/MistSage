import SwiftUI
import SwiftData

struct PublishReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    @State private var title = ""
    @State private var moneyText = ""
    @State private var reason = ""
    @State private var topic: DecisionTopic = .other
    @State private var draftNickname = ""
    @State private var confirmingRegion = false
    @State private var showRegionError = false
    @State private var coolOff: CoolOffPeriod = .day1
    /// 手动选过就不再随金额自动变
    @State private var coolOffPicked = false

    private var money: Double { Double(moneyText) ?? 0 }
    private var needsNickname: Bool { !settings.hasNickname }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!needsNickname || !draftNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                field("想做什么 / 买什么") {
                    TextField(
                        "",
                        text: $title,
                        prompt: Text("一句话写清").foregroundStyle(Theme.placeholder)
                    )
                    .foregroundStyle(Theme.ink)
                    .fieldBox()
                }

                field("类型") {
                    topicPicker
                }

                MoneyField(title: "涉及金额（\(Theme.currencyUnit)）", text: $moneyText)
                    .onChange(of: moneyText) { _, _ in
                        guard !coolOffPicked else { return }
                        withAnimation(.easeOut(duration: 0.16)) {
                            coolOff = CoolOffPeriod.suggested(for: money)
                        }
                    }

                field("冷静期") {
                    VStack(alignment: .leading, spacing: 8) {
                        coolOffPicker
                        Text("冷静期内不能拍板，按金额自动推荐，可手动改。")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }

                field("为什么纠结") {
                    TextField(
                        "",
                        text: $reason,
                        prompt: Text("必须回答自己：为什么需要它").foregroundStyle(Theme.placeholder),
                        axis: .vertical
                    )
                    .lineLimit(3...5)
                    .foregroundStyle(Theme.ink)
                    .fieldBox()
                }

                if needsNickname {
                    NicknameRequiredField(text: $draftNickname)
                }
            }
            .padding(20)
            .padding(.bottom, 88)
        }
        .background(AtmosphereBackground())
        .navigationTitle("征求建议")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }.foregroundStyle(Theme.inkSoft)
            }
        }
        .safeAreaInset(edge: .bottom) {
            SheetBottomBar(
                title: confirmingRegion ? "处理中…" : "发布并开始冷静",
                enabled: canSave && !confirmingRegion,
                action: publish
            )
        }
        .alert("暂时无法发布", isPresented: $showRegionError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("无法确认你的 App Store 地区，请联网后再试。")
        }
    }

    private var topicPicker: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(DecisionTopic.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { topic = item }
                } label: {
                    Text(item.localizedName)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(topic == item ? Color.white : Theme.inkSoft)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(topic == item ? Theme.accent : Theme.paperDeep)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }

    private var coolOffPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(CoolOffPeriod.allCases) { p in
                Button {
                    coolOffPicked = true
                    withAnimation(.easeOut(duration: 0.16)) { coolOff = p }
                } label: {
                    Text(p.label)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(coolOff == p ? Color.white : Theme.inkSoft)
                        .background(Capsule().fill(coolOff == p ? Theme.accent : Theme.paperDeep))
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: title)
            content()
        }
    }

    /// 帖子归哪个区由商店地区决定；没确认过就不发，避免用系统地区兜底归错区
    private func publish() {
        if AppRegion.confirmed != nil {
            save()
            return
        }
        confirmingRegion = true
        Task {
            await AppRegion.refresh()
            confirmingRegion = false
            if AppRegion.confirmed != nil {
                save()
            } else {
                showRegionError = true
            }
        }
    }

    private func save() {
        if needsNickname {
            settings.nickname = draftNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let request = ReviewRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            money: money,
            minutes: 0,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            alternative: "",
            constraints: "",
            status: .cooling,
            topic: topic,
            coolHours: coolOff.hours,
            isPublicOnPlaza: true
        )
        modelContext.insert(request)
        ModelSave.commit(modelContext, successMessage: "已发布，开始冷静")
        Task {
            await NoticeCenter.shared.requestIfNeeded()
            NoticeCenter.scheduleCoolingReminder(for: request)
        }
        dismiss()
    }
}
