import SwiftUI
import SwiftData

struct AddDecisionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    var editing: DecisionRecord?

    @State private var title = ""
    @State private var kind: DecisionKind = .did
    @State private var topic: DecisionTopic = .other
    @State private var moneyText = ""
    @State private var trackTime = false
    @State private var minutes = 0
    @State private var note = ""

    private var money: Double { Double(moneyText) ?? 0 }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewTimeCost: Double {
        guard trackTime, settings.hourlyRate > 0, minutes > 0 else { return 0 }
        return settings.hourlyRate * Double(minutes) / 60.0
    }

    private var moneyFieldTitle: String {
        kind == .did ? "花了多少（元）" : "省了多少（元）"
    }

    private var isEditing: Bool { editing != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TextField(
                    "",
                    text: $title,
                    prompt: Text("例如：想喝奶茶但没喝").foregroundStyle(Theme.placeholder)
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .fieldBox()

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel(text: "类型")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(DecisionTopic.allCases) { item in
                            Button {
                                withAnimation(.easeOut(duration: 0.16)) { topic = item }
                            } label: {
                                Text(item.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(topic == item ? Color.white : Theme.inkSoft)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(topic == item ? Theme.accent : Theme.paperDeep)
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel(text: "结果")
                    kindPicker
                    Text(kind == .did ? "会记入生活成本" : "会记入「省下的代价」")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                MoneyField(title: moneyFieldTitle, text: $moneyText)

                SoftPanel(padding: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $trackTime.animation(.easeOut(duration: 0.16))) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("同时记录时间")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.ink)
                                Text("按设置里的 1 小时时间成本折算")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .tint(Theme.accent)

                        if trackTime {
                            MinutesPickerField(minutes: $minutes)

                            if previewTimeCost > 0 {
                                HStack {
                                    Text("时间代价预览")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.inkSoft)
                                    Spacer()
                                    Text(Theme.money(previewTimeCost))
                                        .font(.system(.body, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Theme.accentDeep)
                                        .monospacedDigit()
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Theme.paperDeep)
                                )
                            } else if settings.hourlyRate <= 0 {
                                Text("可在设置里配置「1小时时间成本」。")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel(text: "备注（可选）")
                    TextField(
                        "",
                        text: $note,
                        prompt: Text("随手写一句").foregroundStyle(Theme.placeholder),
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .foregroundStyle(Theme.ink)
                    .fieldBox()
                }
            }
            .padding(20)
            .padding(.bottom, 88)
        }
        .background(AtmosphereBackground())
        .navigationTitle(isEditing ? "编辑记录" : "记一笔")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }.foregroundStyle(Theme.inkSoft)
            }
        }
        .safeAreaInset(edge: .bottom) {
            SheetBottomBar(title: "保存", enabled: canSave, action: save)
        }
        .onAppear { loadIfNeeded() }
    }

    private var kindPicker: some View {
        HStack(spacing: 8) {
            ForEach(DecisionKind.allCases) { k in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { kind = k }
                } label: {
                    Text(k.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(kind == k ? Color.white : Theme.inkSoft)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(kind == k ? Theme.accent : Theme.paperDeep)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }

    private func loadIfNeeded() {
        guard let record = editing else { return }
        title = record.title
        kind = record.kind
        topic = record.topic
        moneyText = record.money > 0 ? String(format: "%g", record.money) : ""
        trackTime = record.minutes > 0
        minutes = record.minutes
        note = record.note
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let mins = trackTime ? minutes : 0
        let noteText = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let record = editing {
            record.title = trimmed
            record.kind = kind
            record.topic = topic
            record.money = money
            record.minutes = mins
            record.note = noteText
            ModelSave.commit(modelContext, successMessage: "记录已更新")
        } else {
            modelContext.insert(
                DecisionRecord(
                    title: trimmed,
                    kind: kind,
                    topic: topic,
                    money: money,
                    minutes: mins,
                    note: noteText
                )
            )
            ModelSave.commit(modelContext, successMessage: "已记一笔")
        }
        dismiss()
    }
}
