import SwiftUI
import SwiftData

struct ReviewDetailView: View {
    @Bindable var item: ReviewRequest
    /// 从个人主页进入时只读，不可编辑/裁定/投票
    var readOnly: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @Query private var allVotes: [ReviewVote]

    @State private var showGiveSuggestion = false
    @State private var pendingDecision: ReviewStatus?
    @State private var showDeleteConfirm = false

    private var votesForItem: [ReviewVote] {
        allVotes
            .filter { $0.reviewId == item.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var myVote: ReviewVote? {
        votesForItem.first(where: \.isMine)
    }

    private var tally: [ReviewSuggestion: Int] {
        Dictionary(grouping: votesForItem, by: \.suggestion).mapValues(\.count)
    }

    private var canSuggest: Bool { !readOnly && !item.isMine && !item.isClosed }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerBlock

                if !readOnly, item.isMine {
                    ownerSection
                } else if readOnly, item.isClosed {
                    SoftPanel(padding: 14) {
                        Text("已裁定：\(item.status.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }

                resultsBlock
                commentsBlock
            }
            .padding(20)
            .padding(.bottom, canSuggest ? 72 : 16)
        }
        .background(AtmosphereBackground())
        .navigationTitle("建议详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !readOnly, item.isMine, !item.isDemo {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("删除", role: .destructive) { showDeleteConfirm = true }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .confirmationDialog("删除这条征求建议？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { deleteMineReview() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("相关建议也会一并删除，不可恢复。")
        }
        .safeAreaInset(edge: .bottom) {
            if canSuggest {
                Button {
                    showGiveSuggestion = true
                } label: {
                    Text(myVote == nil ? "给出建议" : "修改建议")
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
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showGiveSuggestion) {
            GiveSuggestionSheet(item: item, existingVote: myVote)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .environmentObject(settings)
        }
        .confirmationDialog(
            pendingDecision == .decidedDo ? "确认决定去做？" : "确认决定不做？",
            isPresented: Binding(
                get: { pendingDecision != nil },
                set: { if !$0 { pendingDecision = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("确认，之后不可更改", role: .destructive) {
                guard let pendingDecision else { return }
                item.finalize(as: pendingDecision)
                ModelSave.commit(
                    modelContext,
                    successMessage: pendingDecision == .decidedDo ? "已决定去做" : "已决定不做"
                )
                self.pendingDecision = nil
            }
            Button("取消", role: .cancel) { pendingDecision = nil }
        } message: {
            Text("裁定后不可再改。仍会留在广场，方便别人参考评论与结果。与最终决定一致的建议会记为「被采纳」。")
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink {
                UserProfileView(
                    authorName: item.isMine ? settings.displayName : item.authorName,
                    isMe: item.isMine
                )
            } label: {
                HStack(spacing: 12) {
                    UserAvatarView(
                        name: item.isMine ? settings.displayName : item.authorName,
                        isMe: item.isMine,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.isMine ? settings.displayName : item.authorName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("查看主页")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.placeholder)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surface)
                )
            }
            .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))

            HStack(spacing: 8) {
                tagChip(item.topic.rawValue, fill: Theme.paperDeep, fg: Theme.inkSoft)
                if item.isDemo {
                    tagChip("演示", fill: Theme.paperDeep, fg: Theme.muted)
                }
                Spacer(minLength: 0)
                tagChip(item.status.rawValue, fill: Theme.accentSoft, fg: Theme.accentDeep)
            }

            Text(item.title)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if item.money > 0 {
                HStack(spacing: 8) {
                    Text("涉及金额")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.paperDeep))
                    Text(Theme.money(item.money))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                }
            }

            if !item.reason.isEmpty {
                Text(item.reason)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 我的建议置顶，其余按时间
    private var orderedVotes: [ReviewVote] {
        let mine = votesForItem.filter(\.isMine)
        let others = votesForItem.filter { !$0.isMine }
        return mine + others
    }

    private var resultsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("建议结果")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("共 \(votesForItem.count) 人参与")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }

            if votesForItem.isEmpty {
                Text("还没有人给出建议。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                let total = max(votesForItem.count, 1)
                VStack(spacing: 10) {
                    ForEach(ReviewSuggestion.allCases) { s in
                        let count = tally[s] ?? 0
                        let ratio = Double(count) / Double(total)
                        let filtered = votesForItem.filter { $0.suggestion == s }
                        NavigationLink {
                            SuggestionCommentsView(title: s.rawValue, votes: filtered, review: item)
                        } label: {
                            resultRow(suggestion: s, count: count, ratio: ratio)
                        }
                        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
                        .disabled(count == 0)
                        .opacity(count == 0 ? 0.55 : 1)
                    }
                }
            }
        }
    }

    private func resultRow(suggestion s: ReviewSuggestion, count: Int, ratio: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(count) 人")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(s.tagForeground)
                Text(String(format: "%.0f%%", ratio * 100))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
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
            Text("全部建议")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            if orderedVotes.isEmpty {
                Text("暂无建议。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(orderedVotes, id: \.id) { vote in
                    VoteCommentRow(vote: vote, adopted: vote.isAdopted(by: item))
                }
            }
        }
    }

    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.isClosed {
                SoftPanel(padding: 14) {
                    Text("已裁定：\(item.status.rawValue)。不可再改，仍展示在广场供参考。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            } else {
                Text("你不能给自己提建议。裁定后不可更改，会继续留在广场供他人参考。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)

                PrimaryButton(title: "决定去做") {
                    pendingDecision = .decidedDo
                }
                PrimaryButton(title: "决定不做（计入省下）", filled: false) {
                    pendingDecision = .decidedSkip
                }
            }
        }
    }

    private func tagChip(_ text: String, fill: Color, fg: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }

    private func deleteMineReview() {
        for vote in votesForItem {
            modelContext.delete(vote)
        }
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }
}

struct VoteCommentRow: View {
    let vote: ReviewVote
    var adopted: Bool = false

    var body: some View {
        SoftPanel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                UserAvatarView(
                    name: vote.displayName,
                    isMe: vote.isMine,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(vote.displayName)
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
                        Text(vote.createdAt.formatted(.relative(presentation: .named)))
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
                        Text(vote.suggestion.rawValue)
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
