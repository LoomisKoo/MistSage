import SwiftUI

/// 注销确认：先标记云端账号失效并清本地，再分批删数据
struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloud = CloudSync.shared
    @State private var confirmText = ""
    @State private var showFinalConfirm = false
    @State private var failed = false

    private var confirmKeyword: String { L("注销") }

    private var canConfirm: Bool {
        confirmText.trimmingCharacters(in: .whitespacesAndNewlines) == confirmKeyword
            && !cloud.isDeletingAccount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SoftPanel(padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("注销后不可恢复", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.warn)
                        Text("将永久删除你在雾中仙中的账号与数据，包括：")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                        VStack(alignment: .leading, spacing: 6) {
                            bullet("昵称、头像等个人资料")
                            bullet("决策记录、资产与照片")
                            bullet("你发布的征求建议")
                            bullet("你给出的建议与黑名单")
                        }
                        Text("系统 iCloud 账号本身不会被删除。别人曾给你的建议会随帖子一并从广场消失；举报记录仅保留匿名处理痕迹。")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel(text: "请输入「\(confirmKeyword)」以确认")
                    TextField(
                        "",
                        text: $confirmText,
                        prompt: Text(LocalizedStringKey(confirmKeyword)).foregroundStyle(Theme.placeholder)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.ink)
                    .fieldBox()
                }

                if failed {
                    Text(cloud.lastError ?? L("注销失败，请稍后再试"))
                        .font(.caption)
                        .foregroundStyle(Theme.warn)
                }

                if cloud.isDeletingAccount {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在注销…")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 88)
        }
        .background(AtmosphereBackground())
        .navigationTitle("注销账号")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            SheetBottomBar(
                title: cloud.isDeletingAccount ? "处理中…" : "确认注销",
                enabled: canConfirm
            ) {
                showFinalConfirm = true
            }
        }
        .confirmationDialog("确定注销账号？", isPresented: $showFinalConfirm, titleVisibility: .visible) {
            Button("确认注销", role: .destructive) { submit() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("账号将立即失效，云端数据会在后台清理；中途退出也会在下次打开时继续。")
        }
        .interactiveDismissDisabled(cloud.isDeletingAccount)
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·")
                .foregroundStyle(Theme.muted)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func submit() {
        failed = false
        Task {
            let ok = await cloud.deleteAccount()
            if ok {
                SaveFeedback.post(message: "账号已注销")
                dismiss()
            } else {
                failed = true
            }
        }
    }
}
