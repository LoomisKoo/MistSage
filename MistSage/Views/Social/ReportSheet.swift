import SwiftUI
import SwiftData

extension ModelContext {
    func block(_ userID: String) {
        guard !userID.isEmpty, userID != AccountSession.currentUserID else { return }
        let me = AccountSession.currentUserID
        let existing = (try? fetch(FetchDescriptor<BlockEntry>(
            predicate: #Predicate { $0.blockerID == me && $0.blockedID == userID }
        ))) ?? []
        guard existing.isEmpty else { return }
        insert(BlockEntry(blockedID: userID))
        try? save()
    }

    func unblock(_ userID: String) {
        let me = AccountSession.currentUserID
        let entries = (try? fetch(FetchDescriptor<BlockEntry>(
            predicate: #Predicate { $0.blockerID == me && $0.blockedID == userID }
        ))) ?? []
        for entry in entries { deleteSynced(entry) }
        try? save()
    }
}

/// 举报 + 拉黑的菜单项，放进 Menu 或 contextMenu
struct ModerationMenuItems: View {
    let target: ReportTarget
    @Binding var reporting: ReportTarget?
    @Binding var blockingUserID: String?

    var body: some View {
        Button("举报", systemImage: "exclamationmark.bubble") {
            reporting = target
        }
        if !target.userID.isEmpty {
            Button("拉黑此人", systemImage: "hand.raised", role: .destructive) {
                blockingUserID = target.userID
            }
        }
    }
}

extension View {
    /// 统一的举报表单 + 拉黑确认
    func moderationSheets(
        reporting: Binding<ReportTarget?>,
        blockingUserID: Binding<String?>,
        onBlocked: @escaping (String) -> Void = { _ in }
    ) -> some View {
        modifier(ModerationSheets(reporting: reporting, blockingUserID: blockingUserID, onBlocked: onBlocked))
    }
}

private struct ModerationSheets: ViewModifier {
    @Binding var reporting: ReportTarget?
    @Binding var blockingUserID: String?
    var onBlocked: (String) -> Void
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var cloud = CloudSync.shared
    @ObservedObject private var users = UserDirectory.shared
    @State private var showICloudHint = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { reporting != nil && cloud.canWrite },
                set: { if !$0 { reporting = nil } }
            )) {
                if let reporting {
                    NavigationStack {
                        ReportSheet(target: reporting)
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .confirmationDialog(
                "拉黑「\(users.name(for: blockingUserID ?? ""))」？",
                isPresented: Binding(
                    get: { blockingUserID != nil && cloud.canWrite },
                    set: { if !$0 { blockingUserID = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("拉黑", role: .destructive) {
                    if let id = blockingUserID {
                        modelContext.block(id)
                        SaveFeedback.post(message: "已拉黑")
                        onBlocked(id)
                    }
                    blockingUserID = nil
                }
                Button("取消", role: .cancel) { blockingUserID = nil }
            } message: {
                Text("你将不再看到 TA 的征求建议和建议。可在「设置 - 黑名单」中解除。")
            }
            .onChange(of: reporting != nil || blockingUserID != nil) { _, active in
                guard active, !cloud.canWrite else { return }
                reporting = nil
                blockingUserID = nil
                showICloudHint = true
            }
            .iCloudRequiredAlert(isPresented: $showICloudHint)
    }
}

struct ReportSheet: View {
    let target: ReportTarget
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var detail = ""
    @State private var sending = false
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("请选择举报原因，我们会尽快处理。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)

                VStack(spacing: 8) {
                    ForEach(ReportReason.allCases) { r in
                        Button {
                            reason = r
                        } label: {
                            HStack {
                                Text(r.localizedName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: reason == r ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(reason == r ? Theme.accent : Theme.placeholder)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.surface)
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
                    }
                }

                TextField(
                    "",
                    text: $detail,
                    prompt: Text("补充说明（可选）").foregroundStyle(Theme.placeholder),
                    axis: .vertical
                )
                .lineLimit(3...6)
                .foregroundStyle(Theme.ink)
                .fieldBox()

                if failed {
                    Text(CloudSync.shared.lastError ?? L("提交失败，请稍后再试"))
                        .font(.caption)
                        .foregroundStyle(Theme.warn)
                }
            }
            .padding(20)
            .padding(.bottom, 88)
        }
        .background(AtmosphereBackground())
        .navigationTitle("举报")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }.foregroundStyle(Theme.inkSoft)
            }
        }
        .safeAreaInset(edge: .bottom) {
            SheetBottomBar(title: sending ? "提交中…" : "提交", enabled: reason != nil && !sending) {
                submit()
            }
        }
    }

    private func submit() {
        guard let reason else { return }
        sending = true
        failed = false
        Task {
            let ok = await CloudSync.shared.report(
                target,
                reason: reason,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            sending = false
            if ok {
                SaveFeedback.post(message: "已提交举报，感谢反馈")
                dismiss()
            } else {
                failed = true
            }
        }
    }
}

struct BlockListView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var users = UserDirectory.shared
    @Query(sort: \BlockEntry.createdAt, order: .reverse) private var blocks: [BlockEntry]

    var body: some View {
        Group {
            if blocks.isEmpty {
                EmptyHint(
                    systemImage: "hand.raised",
                    title: "黑名单是空的",
                    message: "在用户主页或建议详情里可以拉黑别人。"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(blocks, id: \.blockedID) { entry in
                        HStack(spacing: 12) {
                            UserAvatarView(userID: entry.blockedID, size: 36)
                            Text(users.name(for: entry.blockedID))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Button("解除") {
                                modelContext.unblock(entry.blockedID)
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AtmosphereBackground())
        .navigationTitle("黑名单")
        .navigationBarTitleDisplayMode(.inline)
    }
}
