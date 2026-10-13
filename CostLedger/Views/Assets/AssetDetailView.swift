import SwiftUI

struct AssetDetailView: View {
    @Bindable var item: AssetItem
    /// 从个人主页进入时只读
    var readOnly: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                if let photo = item.photoImage {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.accentSoft)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: item.resolvedIcon)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if !item.summary.isEmpty {
                            Text(item.summary)
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }

                SoftPanel(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("使用情况")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                        Text(item.utilizationHint)
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    stat("类型", item.kind.rawValue)
                    stat("价值", Theme.money(item.price))
                    if let cpu = item.costPerUse {
                        stat("单次成本", Theme.money(cpu))
                    }
                    if let avg = item.avgDaysPerUse {
                        stat("平均间隔", String(format: "%.0f 天/次", avg))
                    } else {
                        stat("累计使用", "\(item.useCount) 次")
                    }
                    stat("闲置", "\(item.idleDays) 天")
                    if item.kind.tracksStock {
                        stat("存量", item.status.rawValue)
                    }
                    stat("入手时间", item.purchasedAt.formatted(date: .abbreviated, time: .omitted))
                }

                if item.isIdle {
                    SoftPanel(padding: 14) {
                        Label("很久没用了，可以考虑出二手或送人。", systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(Theme.warn)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, readOnly ? 0 : 24)
        }
        .background(AtmosphereBackground())
        .navigationTitle("资产详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !readOnly {
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
        }
        .safeAreaInset(edge: .bottom) {
            if !readOnly {
                PrimaryButton(title: "用了一次") {
                    item.markUsed()
                }
                .sensoryFeedback(.impact(weight: .light), trigger: item.useCount)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .confirmationDialog("删除这个资产？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                item.setPhoto(nil)
                modelContext.delete(item)
                try? modelContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不可恢复。")
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                AddAssetView(editing: item)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
                    .lineLimit(1)
            }
        }
    }
}
