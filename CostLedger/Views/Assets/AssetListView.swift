import SwiftUI
import SwiftData

struct AssetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetItem.createdAt, order: .reverse) private var assets: [AssetItem]

    var body: some View {
        Group {
            if assets.isEmpty {
                EmptyHint(
                    systemImage: "shippingbox",
                    title: "资产柜是空的",
                    message: "点右下角 + → 资产。用了点一下，久不用会提醒。"
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(assets, id: \.id) { item in
                        NavigationLink {
                            AssetDetailView(item: item)
                        } label: {
                            AssetCard(item: item)
                        }
                        .navigationLinkIndicatorVisibility(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                item.setPhoto(nil)
                                modelContext.delete(item)
                                try? modelContext.save()
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                item.markUsed()
                                try? modelContext.save()
                            } label: {
                                Label("用了", systemImage: "plus.circle")
                            }
                            .tint(Theme.accent)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 56)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AtmosphereBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("资产柜")
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}

struct AssetCard: View {
    let item: AssetItem

    var body: some View {
        SoftPanel(padding: 16) {
            HStack(spacing: 14) {
                Group {
                    if let photo = item.photoImage {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(item.isIdle ? Theme.warnSoft : Theme.accentSoft)
                            .overlay(
                                Image(systemName: item.resolvedIcon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(item.isIdle ? Theme.warn : Theme.accent)
                            )
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(item.kind.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accentDeep)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.accentSoft))
                    }

                    HStack(spacing: 10) {
                        if let cpu = item.costPerUse, item.useCount > 0 {
                            Text("单次 \(Theme.money(cpu))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.inkSoft)
                                .monospacedDigit()
                        } else if item.price > 0 {
                            Text(Theme.money(item.price))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.inkSoft)
                                .monospacedDigit()
                        }
                        if let avg = item.avgDaysPerUse {
                            Text(String(format: "%.0f天/次", avg))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        } else {
                            Text("用过 \(item.useCount) 次")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        if item.isIdle {
                            Text("闲置 \(item.idleDays) 天")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.warn)
                        }
                    }
                }
            }
        }
    }
}
