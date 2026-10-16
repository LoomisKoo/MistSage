import SwiftUI
import SwiftData

struct ReviewDetailView: View {
    @Bindable var item: ReviewRequest
    /// 从个人主页进入时只读，不可编辑/拍板/投票
    var readOnly: Bool = false
    /// 仅从「决策」页进入时为 true：可删除、拍板做不做
    var canManage: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var users = UserDirectory.shared
    @ObservedObject private var cloud = CloudSync.shared
    @Query private var allVotes: [ReviewVote]
    @Query private var blocks: [BlockEntry]

    @State private var showGiveSuggestion = false
    @State private var pendingDecision: ReviewStatus?
    @State private var showDeleteConfirm = false
    @State private var showICloudHint = false
    @State private var reporting: ReportTarget?
    @State private var blockingUserID: String?

    private var blockedIDs: Set<String> { Set(blocks.map(\.blockedID)) }

    private var votesForItem: [ReviewVote] {
        allVotes
            .filter {
                $0.reviewId == item.id
                    && ($0.isMine || (!blockedIDs.contains($0.voterID) && !users.isDeleted($0.voterID)))
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var myVote: ReviewVote? {
        votesForItem.first(where: \.isMine)
    }

    private var tally: [ReviewSuggestion: Int] {
        Dictionary(grouping: votesForItem, by: \.suggestion).mapValues(\.count)
    }

    private var canSuggest: Bool { !readOnly && !item.isMine && !item.isClosed }
    private var showOwnerActions: Bool { canManage && item.isMine }
    private var showBottomDecideBar: Bool { showOwnerActions && !item.isClosed }
    private var needsBottomInset: Bool { canSuggest || showBottomDecideBar }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerBlock
                    .padding(.bottom, 28)

                if votesForItem.isEmpty {
                    emptySuggestions
                } else {
                    resultsBlock
                        .padding(.bottom, 28)
                    commentsBlock
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, needsBottomInset ? 88 : 32)
        }
        .background(AtmosphereBackground())
        .navigationTitle("征求建议")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavigationLink {
                    UserProfileView(userID: item.authorID)
                } label: {
                    HStack(spacing: 8) {
                        UserAvatarView(userID: item.authorID, size: 36)
                        Text(users.name(for: item.authorID))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
            if showOwnerActions {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("删除", role: .destructive) { showDeleteConfirm = true }
                        .font(.body.weight(.semibold))
                }
            } else if !item.isMine {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ModerationMenuItems(
                            target: .review(item),
                            reporting: $reporting,
                            blockingUserID: $blockingUserID
                        )
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
        .moderationSheets(reporting: $reporting, blockingUserID: $blockingUserID) {
            if $0 == item.authorID { dismiss() }
        }
        .alert("删除这条征求建议？", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) { deleteMineReview() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("相关建议也会一并删除，不可恢复。")
        }
        .safeAreaInset(edge: .bottom) {
            if showBottomDecideBar, item.isCooling, let coolUntil = item.coolUntil {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let minutes = max(1, Int(ceil(coolUntil.timeIntervalSince(context.date) / 60)))
                    Text("冷静中 · 剩 \(Theme.remaining(minutes: minutes))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.paperDeep)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            } else if showBottomDecideBar {
                HStack(spacing: 12) {
                    decideBarButton(
                        title: "拍板 · 做",
                        foreground: Theme.accentDeep,
                        background: Theme.accentSoft
                    ) {
                        pendingDecision = .decidedDo
                    }
                    decideBarButton(
                        title: "拍板 · 不做",
                        foreground: Theme.warn,
                        background: Theme.warnSoft
                    ) {
                        pendingDecision = .decidedSkip
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            } else if canSuggest {
                Button {
                    if cloud.canWrite {
                        showGiveSuggestion = true
                    } else {
                        showICloudHint = true
                    }
                } label: {
                    Text(myVote == nil ? LocalizedStringKey("给出建议") : LocalizedStringKey("修改建议"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.accent)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $showGiveSuggestion) {
            GiveSuggestionSheet(item: item, existingVote: myVote)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .environmentObject(settings)
        }
        .iCloudRequiredAlert(isPresented: $showICloudHint)
        .alert(
            pendingDecision == .decidedDo ? "确认拍板 · 做？" : "确认拍板 · 不做？",
            isPresented: Binding(
                get: { pendingDecision != nil },
                set: { if !$0 { pendingDecision = nil } }
            )
        ) {
            Button("确认，之后不可更改", role: .destructive) {
                guard let pendingDecision else { return }
                item.finalize(as: pendingDecision)
                NoticeCenter.cancelCoolingReminder(for: item)
                for voterID in Set(votesForItem.map(\.voterID)) {
                    modelContext.enqueueNotice(to: voterID, kind: .decided, review: item)
                }
                ModelSave.commit(
                    modelContext,
                    successMessage: pendingDecision == .decidedDo ? "已拍板 · 做" : "已拍板 · 不做"
                )
                self.pendingDecision = nil
            }
            Button("取消", role: .cancel) { pendingDecision = nil }
        } message: {
            Text("拍板后不可再改。仍会留在广场，方便别人参考评论与结果。与最终决定一致的建议会记为「被采纳」。")
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(item.title)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !item.reason.isEmpty {
                Text(item.reason)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
            }

            metaLine
        }
    }

    /// 类型 / 状态用小标签，金额另起一行弱文案
    private var metaLine: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MetaTag(text: item.topic.localizedName, fg: Theme.inkSoft, bg: Theme.paperDeep)
                MetaTag(text: item.status.badgeName, fg: statusFg, bg: statusBg)
                Spacer(minLength: 0)
            }
            if item.money > 0 {
                Text(Theme.money(item.money))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
            }
        }
    }

    private var statusFg: Color {
        if item.isOverdue { return Theme.warn }
        switch item.status {
        case .decidedSkip: return Theme.accentDeep
        case .decidedDo: return Theme.warn
        default: return Theme.inkSoft
        }
    }

    private var statusBg: Color {
        if item.isOverdue { return Theme.warnSoft }
        switch item.status {
        case .decidedSkip: return Theme.accentSoft
        case .decidedDo: return Theme.warnSoft
        default: return Theme.paperDeep
        }
    }

    private var emptySuggestions: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(Theme.line.opacity(0.7))
                .frame(height: 1)
                .padding(.bottom, 18)
            Text("还没有人给出建议")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            Text(item.isMine ? LocalizedStringKey("别人的建议会出现在这里。") : LocalizedStringKey("成为第一个给建议的人吧。"))
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// 我的建议置顶，其余按时间
    private var orderedVotes: [ReviewVote] {
        let mine = votesForItem.filter(\.isMine)
        let others = votesForItem.filter { !$0.isMine }
        return mine + others
    }

    /// 旧帖里有人选过「缓一缓」才显示这一行
    private var resultOptions: [ReviewSuggestion] {
        (tally[.wait] ?? 0) > 0 ? [.doIt, .wait, .skip] : ReviewSuggestion.selectable
    }

    private var resultsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Theme.line.opacity(0.7))
                .frame(height: 1)
                .padding(.bottom, 6)

            HStack(alignment: .firstTextBaseline) {
                Text("结果")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(votesForItem.count) 人")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.placeholder)
            }

            let total = max(votesForItem.count, 1)
            VStack(spacing: 8) {
                ForEach(resultOptions) { s in
                    let count = tally[s] ?? 0
                    let ratio = Double(count) / Double(total)
                    let filtered = votesForItem.filter { $0.suggestion == s }
                    NavigationLink {
                        SuggestionCommentsView(title: s.shortName, votes: filtered, review: item)
                    } label: {
                        resultRow(suggestion: s, count: count, ratio: ratio)
                    }
                    .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
                    .disabled(count == 0)
                }
            }
        }
    }

    private func resultRow(suggestion s: ReviewSuggestion, count: Int, ratio: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(s.shortName) (\(count))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(String(format: "%.0f%%", ratio * 100))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
                if count > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.placeholder)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.paperDeep)
                    Capsule()
                        .fill(s.tagForeground.opacity(0.85))
                        .frame(width: max(count > 0 ? 8 : 0, geo.size.width * ratio))
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surface)
        )
    }

    private var commentsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建议")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)

            ForEach(orderedVotes, id: \.id) { vote in
                VoteCommentRow(vote: vote, adopted: vote.isAdopted(by: item))
                    .contextMenu {
                        if !vote.isMine {
                            ModerationMenuItems(
                                target: .vote(vote),
                                reporting: $reporting,
                                blockingUserID: $blockingUserID
                            )
                        }
                    }
            }
        }
    }

    private func decideBarButton(
        title: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(background)
                )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func deleteMineReview() {
        // 别人的建议没有权限删，云端只删帖子本身，本地一并清掉
        for vote in votesForItem {
            if vote.isMine {
                modelContext.deleteSynced(vote)
            } else {
                modelContext.delete(vote)
            }
        }
        NoticeCenter.cancelCoolingReminder(for: item)
        modelContext.deleteSynced(item)
        try? modelContext.save()
        dismiss()
    }
}

struct VoteCommentRow: View {
    let vote: ReviewVote
    var adopted: Bool = false
    @ObservedObject private var users = UserDirectory.shared

    var body: some View {
        SoftPanel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                UserAvatarView(userID: vote.voterID, size: 40)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(users.name(for: vote.voterID))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if vote.isMine {
                            Text("我")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.accent))
                        }
                        Text(vote.createdAt.appRelative())
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                        if adopted {
                            Text("被采纳")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.accentDeep))
                        }
                        Spacer(minLength: 0)
                        Text(vote.suggestion.shortName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(vote.suggestion.tagForeground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(vote.suggestion.tagFill))
                    }

                    if vote.comment.isEmpty {
                        Text("（未填写理由）")
                            .font(.subheadline)
                            .foregroundStyle(Theme.placeholder)
                    } else {
                        Text(vote.comment)
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

extension ReviewSuggestion {
    var tagFill: Color {
        switch self {
        case .doIt: return Theme.accentSoft
        case .wait: return Theme.paperDeep
        case .skip: return Theme.warnSoft
        }
    }

    var tagForeground: Color {
        switch self {
        case .doIt: return Theme.accentDeep
        case .wait: return Theme.inkSoft
        case .skip: return Theme.warn
        }
    }
}
