import SwiftUI
import SwiftData

/// 给出 / 修改建议
struct GiveSuggestionSheet: View {
    @Bindable var item: ReviewRequest
    var existingVote: ReviewVote?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    @State private var draftSuggestion: ReviewSuggestion = .wait
    @State private var draftComment = ""

    private var isEditing: Bool { existingVote != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(isEditing ? "可以改选项和理由。" : "选一个倾向，并写一句理由。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)

                    HStack(spacing: 8) {
                        ForEach(ReviewSuggestion.allCases) { s in
                            Button { draftSuggestion = s } label: {
                                Text(s.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(draftSuggestion == s ? Color.white : Theme.inkSoft)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(draftSuggestion == s ? Theme.accent : Theme.surface)
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }

                    TextField(
                        "",
                        text: $draftComment,
                        prompt: Text("写一句理由（建议填写）").foregroundStyle(Theme.placeholder),
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .foregroundStyle(Theme.ink)
                    .fieldBox()
                }
                .padding(20)
                .padding(.bottom, 88)
            }
            .background(AtmosphereBackground())
            .navigationTitle(isEditing ? "修改建议" : "给出建议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Theme.inkSoft)
                }
            }
            .safeAreaInset(edge: .bottom) {
                SheetBottomBar(
                    title: isEditing ? "保存修改" : "提交建议",
                    enabled: true,
                    action: save
                )
            }
            .onAppear {
                if item.isClosed {
                    dismiss()
                    return
                }
                if let existingVote {
                    draftSuggestion = existingVote.suggestion
                    draftComment = existingVote.comment
                }
            }
        }
    }

    private func save() {
        guard !item.isClosed else {
            dismiss()
            return
        }
        let comment = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingVote {
            existingVote.suggestion = draftSuggestion
            existingVote.comment = comment
            existingVote.authorName = settings.displayName
            ModelSave.commit(modelContext, successMessage: "建议已更新")
        } else {
            modelContext.insert(
                ReviewVote(
                    reviewId: item.id,
                    suggestion: draftSuggestion,
                    comment: comment,
                    isMine: true,
                    authorName: settings.displayName
                )
            )
            if item.status == .cooling {
                item.status = .pending
            }
            ModelSave.commit(modelContext, successMessage: "建议已提交")
        }
        dismiss()
    }
}
