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
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(record.title)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        tag(record.kind.localizedName, fg: tone, bg: toneSoft)
                        tag(record.topic.localizedName, fg: Theme.inkSoft, bg: Theme.paperDeep)
                        Spacer(minLength: 8)
                        Text(record.createdAt.appFormatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }

                if record.money > 0 || record.minutes > 0 {
                    HStack(alignment: .top, spacing: 0) {
                        if record.money > 0 {
                            stat(LocalizedStringKey(record.kind.moneyLabel), Theme.money(record.money))
                        }
                        if record.minutes > 0 {
                            stat("耗时", Theme.duration(minutes: record.minutes))
                            if settings.hourlyRate > 0 {
                                stat("时间代价", Theme.money(record.timeCost(hourlyRate: settings.hourlyRate)))
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.surface)
                    )
                }

                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 32)
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
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
        }
        .confirmationDialog("删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                modelContext.deleteSynced(record)
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

    private func tag(_ text: String, fg: Color, bg: Color) -> some View {
        MetaTag(text: text, fg: fg, bg: bg)
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
