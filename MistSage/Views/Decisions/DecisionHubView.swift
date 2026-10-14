import SwiftUI
import SwiftData

enum DecisionHubSegment: String, CaseIterable, Identifiable {
    case pending = "待决"
    case settled = "已决"

    var id: String { rawValue }
}

/// 决策 Tab：征求建议（待决）+ 直接记录（已决）
struct DecisionHubView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \ReviewRequest.createdAt, order: .reverse) private var reviews: [ReviewRequest]
    @Query(sort: \DecisionRecord.createdAt, order: .reverse) private var decisions: [DecisionRecord]

    @State private var segment: DecisionHubSegment = .pending

    private var mineReviews: [ReviewRequest] {
        reviews.filter(\.isMine)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $segment) {
                ForEach(DecisionHubSegment.allCases) { item in
                    Text(item.localizedName).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Group {
                switch segment {
                case .pending:
                    pendingList
                case .settled:
                    settledList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AtmosphereBackground())
    }

    @ViewBuilder
    private var pendingList: some View {
        if mineReviews.isEmpty {
            EmptyHint(
                systemImage: "lightbulb",
                title: "还没有待决事项",
                message: "纠结要不要做的事，点右下角 + → 决策 → 征求建议。"
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(mineReviews, id: \.id) { item in
                    NavigationLink {
                        ReviewDetailView(item: item, canManage: true)
                    } label: {
                        ReviewRow(
                            item: item,
                            hourlyRate: settings.hourlyRate,
                            showAuthor: false
                        )
                    }
                    .navigationLinkIndicatorVisibility(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteReview(item)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 56)
        }
    }

    @ViewBuilder
    private var settledList: some View {
        if decisions.isEmpty {
            EmptyHint(
                systemImage: "square.and.pencil",
                title: "还没有已决记录",
                message: "小事只记不征求建议。点右下角 + → 决策 → 直接记录。"
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(decisions, id: \.id) { record in
                    NavigationLink {
                        DecisionDetailView(record: record)
                    } label: {
                        DecisionRow(record: record, hourlyRate: settings.hourlyRate)
                    }
                    .navigationLinkIndicatorVisibility(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.deleteSynced(record)
                            try? modelContext.save()
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 56)
        }
    }

    private func deleteReview(_ item: ReviewRequest) {
        let votes = ((try? modelContext.fetch(FetchDescriptor<ReviewVote>())) ?? [])
            .filter { $0.reviewId == item.id }
        for vote in votes {
            if vote.isMine {
                modelContext.deleteSynced(vote)
            } else {
                modelContext.delete(vote)
            }
        }
        modelContext.deleteSynced(item)
        try? modelContext.save()
    }
}
