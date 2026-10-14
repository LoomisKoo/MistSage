import SwiftUI
import SwiftData

/// 我参与过（投过票）的建议
struct ParticipatedReviewsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \ReviewVote.createdAt, order: .reverse) private var votes: [ReviewVote]
    @Query private var reviews: [ReviewRequest]
    @ObservedObject private var users = UserDirectory.shared

    private var participated: [(vote: ReviewVote, review: ReviewRequest)] {
        votes.compactMap { vote in
            guard vote.isMine,
                  let review = reviews.first(where: { $0.id == vote.reviewId }) else { return nil }
            return (vote, review)
        }
    }

    var body: some View {
        Group {
            if participated.isEmpty {
                EmptyHint(
                    systemImage: "bubble.left.and.bubble.right",
                    title: "还没参与过",
                    message: "去「广场」给别人的纠结提建议。"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(participated, id: \.vote.id) { pair in
                            NavigationLink {
                                ReviewDetailView(item: pair.review)
                            } label: {
                                SoftPanel(padding: 16) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(users.name(for: pair.review.authorID))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Theme.accentDeep)
                                            if pair.vote.isAdopted(by: pair.review) {
                                                Text("被采纳")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Theme.accent))
                                            }
                                            Spacer()
                                            Text(pair.vote.suggestion.localizedName)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Theme.accentDeep)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(Theme.accentSoft))
                                        }
                                        Text(pair.review.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Theme.ink)
                                            .multilineTextAlignment(.leading)
                                        if !pair.vote.comment.isEmpty {
                                            Text(pair.vote.comment)
                                                .font(.subheadline)
                                                .foregroundStyle(Theme.inkSoft)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(AtmosphereBackground())
        .navigationTitle("我参与的建议")
        .navigationBarTitleDisplayMode(.inline)
    }
}
