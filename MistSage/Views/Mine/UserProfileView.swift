import SwiftUI
import SwiftData

private enum ProfileContentTab: String, CaseIterable, Identifiable {
    case decisions = "决策"
    case assets = "资产"

    var id: String { rawValue }
}

/// 广场用户主页：资料从用户表查，帖子按作者 ID 聚合
struct UserProfileView: View {
    let userID: String

    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var users = UserDirectory.shared
    @Query(sort: \ReviewRequest.createdAt, order: .reverse) private var reviews: [ReviewRequest]
    @Query(sort: \AssetItem.createdAt, order: .reverse) private var assets: [AssetItem]
    @Query private var votes: [ReviewVote]
    @Query private var blocks: [BlockEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var tab: ProfileContentTab = .decisions
    @State private var remoteAssets: [AssetItem] = []
    @State private var reporting: ReportTarget?
    @State private var blockingUserID: String?

    private var isMe: Bool { users.isMe(userID) }
    private var isBlocked: Bool { blocks.contains { $0.blockedID == userID } }

    private var displayName: String { users.name(for: userID) }

    private var publicDecisions: [ReviewRequest] {
        reviews.filter { $0.authorID == userID && ($0.isPublicOnPlaza || isMe) }
    }

    private var publicAssets: [AssetItem] {
        isMe ? assets.filter(\.isPublic) : remoteAssets
    }

    private var genderLabel: String? {
        users.gender(for: userID).publicLabel
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
                    statCard("征求建议", "\(publicDecisions.count)", L("进行中 \(openCount)"))
                    statCard("公开资产", "\(publicAssets.count)", L("仅展示已公开"))
                }

                Picker("", selection: $tab) {
                    ForEach(ProfileContentTab.allCases) { item in
                        Text(item.localizedName).tag(item)
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
        .toolbar {
            if !isMe {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("举报", systemImage: "exclamationmark.bubble") {
                            reporting = .user(userID)
                        }
                        if isBlocked {
                            Button("解除拉黑", systemImage: "hand.raised.slash") {
                                modelContext.unblock(userID)
                            }
                        } else {
                            Button("拉黑此人", systemImage: "hand.raised", role: .destructive) {
                                blockingUserID = userID
                            }
                        }
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
        .moderationSheets(reporting: $reporting, blockingUserID: $blockingUserID)
        .task(id: userID) {
            guard !isMe else { return }
            remoteAssets = await CloudSync.shared.fetchPublicAssets(of: userID)
        }
    }

    private var header: some View {
        SoftPanel(padding: 18) {
            HStack(spacing: 14) {
                UserAvatarView(userID: userID, size: 64)

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
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.accentSoft)
                        )
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
                    : "TA 还没有公开的资产。"
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

    private func statCard(_ title: LocalizedStringKey, _ value: String, _ footnote: String) -> some View {
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
                        Text(item.topic.localizedName)
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
                        Text(item.createdAt.appFormatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer(minLength: 0)

                Text(item.status.localizedName)
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
