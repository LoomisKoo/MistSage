import SwiftUI
import SwiftData

struct DecisionDetailView: View {
    @Bindable var record: DecisionRecord
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var tone: Color {
        record.kind == .skipped ? Theme.accentDeep : Theme.inkSoft
    }

    private var toneSoft: Color {
        record.kind == .skipped ? Theme.accentSoft : Theme.paperDeep
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                SoftPanel(padding: 18) {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(toneSoft)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: record.kind.symbol)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(tone)
                            )

                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.title)
                                .font(.system(.title3, design: .serif).weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 8) {
                                Text(record.kind.rawValue)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(tone)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(toneSoft))
                                Text(record.topic.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.inkSoft)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Theme.paperDeep))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if record.money > 0 {
                        stat(record.kind.moneyLabel, Theme.money(record.money))
                    }
                    if record.minutes > 0 {
                        stat("时间", "\(record.minutes) 分")
                        if settings.hourlyRate > 0 {
                            stat("时间代价", Theme.money(record.timeCost(hourlyRate: settings.hourlyRate)))
                        }
                    }
                    stat("记录时间", record.createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                if !record.note.isEmpty {
                    SoftPanel(padding: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("备注")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.muted)
                            Text(record.note)
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AtmosphereBackground())
        .navigationTitle("已决详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("编辑") { showEdit = true }
                    Button("删除", role: .destructive) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .confirmationDialog("删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                modelContext.delete(record)
                try? modelContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不可恢复。")
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                AddDecisionView(editing: record)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .environmentObject(settings)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        SoftPanel(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
            }
        }
    }
}
