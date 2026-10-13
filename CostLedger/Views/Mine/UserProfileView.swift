import SwiftUI
import SwiftData

private enum ProfileContentTab: String, CaseIterable, Identifiable {
    case decisions = "决策"
    case assets = "资产"

    var id: String { rawValue }
}

/// 广场用户主页（本地按昵称聚合）
struct UserProfileView: View {
    let authorName: String
    var isMe: Bool = false

    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \ReviewRequest.createdAt, order: .reverse) private var reviews: [ReviewRequest]
    @Query(sort: \AssetItem.createdAt, order: .reverse) private var assets: [AssetItem]
    @Query private var votes: [ReviewVote]

    @State private var tab: ProfileContentTab = .decisions

    private var displayName: String {
        isMe ? settings.displayName : authorName
    }

    private var publicDecisions: [ReviewRequest] {
        if isMe {
            return reviews.filter(\.isMine)
        }
        return reviews.filter { !$0.isMine && $0.authorName == authorName }
    }

    private var publicAssets: [AssetItem] {
        guard isMe else { return [] }
        return assets.filter(\.isPublic)
    }

    private var genderLabel: String? {
        isMe ? settings.gender.publicLabel : nil
    }

    private var openCount: Int {
        publicDecisions.filter { !$0.isClosed }.count
    }

    private var closedCount: Int {
        publicDecisions.filter(\.isClosed).count
    }

    private var adoptedAsAdvisor: Int {
        guard isMe else { return 0 }
        return votes.filter { vote in
            guard vote.isMine,
                  let review = reviews.first(where: { $0.id == vote.reviewId }),
                  !review.isMine
            else { return false }
            return vote.isAdopted(by: review)
        }.count
    }

    private var titleText: String {
        if isMe {
            return AdvisorRank.title(adoptedCount: adoptedAsAdvisor)
        }
        return AdvisorRank.title(adoptedCount: closedCount)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard("征求建议", "\(publicDecisions.count)", "进行中 \(openCount)")
                    statCard("公开资产", "\(publicAssets.count)", isMe ? "仅展示已公开" : "演示用户暂无")
                }

                Picker("", selection: $tab) {
                    ForEach(ProfileContentTab.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch tab {
                    case .decisions:
                        decisionsList
                    case .assets:
                        assetsList
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AtmosphereBackground())
        .navigationTitle("用户主页")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        SoftPanel(padding: 18) {
            HStack(spacing: 14) {
                UserAvatarView(name: displayName, isMe: isMe, size: 64)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(displayName)
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if let genderLabel {
                            Text(genderLabel)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.inkSoft)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.paperDeep))
                        }
                    }
                    Text(titleText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accentDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accentSoft))
                    if isMe {
                        Text("就是你 · 主页预览")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var decisionsList: some View {
        if publicDecisions.isEmpty {
            EmptyHint(
                systemImage: "lightbulb",
                title: "还没有征求建议",
                message: isMe ? "发起征求建议后会出现在这里。" : "TA 还没有公开的决策。"
            )
            .frame(minHeight: 180)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(publicDecisions, id: \.id) { item in
                    NavigationLink {
                        ReviewDetailView(item: item, readOnly: true)
                    } label: {
                        ProfileDecisionRow(item: item)
                    }
                    .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
                }
            }
        }
    }

    @ViewBuilder
    private var assetsList: some View {
        if publicAssets.isEmpty {
            EmptyHint(
                systemImage: "shippingbox",
                title: "没有公开资产",
                message: isMe
                    ? "登记资产时打开「在个人主页公开」，才会出现在这里。"
                    : "演示用户暂无公开资产。"
            )
            .frame(minHeight: 180)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(publicAssets, id: \.id) { item in
                    NavigationLink {
                        AssetDetailView(item: item, readOnly: true)
                    } label: {
                        AssetCard(item: item)
                    }
                    .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
                }
            }
        }
    }

    private func statCard(_ title: String, _ value: String, _ footnote: String) -> some View {
        SoftPanel(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

/// 主页决策列表：更轻、更像信息流
private struct ProfileDecisionRow: View {
    let item: ReviewRequest

    var body: some View {
        SoftPanel(padding: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(item.topic.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        if item.money > 0 {
                            Text("·")
                                .foregroundStyle(Theme.placeholder)
                            Text(Theme.money(item.money))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.inkSoft)
                                .monospacedDigit()
                        }
                        Text("·")
                            .foregroundStyle(Theme.placeholder)
                        Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer(minLength: 0)

                Text(item.status.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(statusFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(statusBg))

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.placeholder)
            }
        }
    }

    private var statusFg: Color {
        switch item.status {
        case .decidedSkip: return Theme.accentDeep
        case .decidedDo: return Theme.warn
        default: return Theme.inkSoft
        }
    }

    private var statusBg: Color {
        switch item.status {
        case .decidedSkip: return Theme.accentSoft
        case .decidedDo: return Theme.warnSoft
        default: return Theme.paperDeep
        }
    }
}
