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
                                modelContext.deleteSynced(item)
                                try? modelContext.save()
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if item.kind.tracksUsage {
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
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 84, for: .scrollContent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AtmosphereBackground())
    }
}

struct AssetCard: View {
    let item: AssetItem

    var body: some View {
        SoftPanel(padding: 10) {
            HStack(spacing: 12) {
                Group {
                    if let photo = item.photoImage {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(item.isIdle ? Theme.warnSoft : Theme.accentSoft)
                            .overlay(
                                Image(systemName: item.resolvedIcon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(item.isIdle ? Theme.warn : Theme.accent)
                            )
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        MetaTag(text: item.kind.localizedName, fg: Theme.accentDeep, bg: Theme.accentSoft)
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
                        if !item.kind.tracksUsage {
                            Text("已收藏 \(item.ownedDays) 天")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        } else {
                            if let avg = item.avgDaysPerUse {
                                Text(String(format: L("%.0f天/次"), avg))
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            } else {
                                Text("用过 \(item.useCount) 次")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            if item.needsRestock {
                                Text(item.status.localizedName)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.warn)
                            } else if item.isIdle {
                                Text("闲置 \(item.idleDays) 天")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.warn)
                            }
                        }
                    }
                }
                .padding(.trailing, 6)
            }
        }
    }
}
