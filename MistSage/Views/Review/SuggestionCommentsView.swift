import SwiftUI

/// 某一类建议意见列表（从建议结果点进）
struct SuggestionCommentsView: View {
    let title: String
    let votes: [ReviewVote]
    var review: ReviewRequest? = nil

    var body: some View {
        Group {
            if votes.isEmpty {
                EmptyHint(
                    systemImage: "lightbulb",
                    title: "暂无此类意见",
                    message: "还没有人给出这个选项。"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(votes, id: \.id) { vote in
                            VoteCommentRow(
                                vote: vote,
                                adopted: review.map { vote.isAdopted(by: $0) } ?? false
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AtmosphereBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
