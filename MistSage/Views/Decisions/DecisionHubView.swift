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
        reviews.filter { $0.isMine && !$0.isClosed }
    }

    private enum SettledItem: Identifiable {
        case record(DecisionRecord)
        case review(ReviewRequest)

        var id: UUID {
            switch self {
            case .record(let r): return r.id
            case .review(let r): return r.id
            }
        }

        var date: Date {
            switch self {
            case .record(let r): return r.createdAt
            case .review(let r): return r.decidedAt ?? r.createdAt
            }
        }
    }

    /// 直接记录 + 已有结论的征求建议，按时间倒序
    private var settledItems: [SettledItem] {
        let closed = reviews.filter { $0.isMine && $0.isClosed }.map(SettledItem.review)
        return (decisions.map(SettledItem.record) + closed).sorted { $0.date > $1.date }
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
            .contentMargins(.bottom, 84, for: .scrollContent)
        }
    }

    @ViewBuilder
    private var settledList: some View {
        if settledItems.isEmpty {
            EmptyHint(
                systemImage: "square.and.pencil",
                title: "还没有已决记录",
                message: "小事只记不征求建议。点右下角 + → 决策 → 直接记录。"
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(settledItems) { entry in
                    Group {
                        switch entry {
                        case .record(let record):
                            NavigationLink {
                                DecisionDetailView(record: record)
                            } label: {
                                DecisionRow(record: record, hourlyRate: settings.hourlyRate)
                            }
                        case .review(let item):
                            NavigationLink {
                                ReviewDetailView(item: item, canManage: true)
                            } label: {
                                ReviewRow(item: item, hourlyRate: settings.hourlyRate, showAuthor: false)
                            }
                        }
                    }
                    .navigationLinkIndicatorVisibility(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            switch entry {
                            case .record(let record):
                                modelContext.deleteSynced(record)
                                try? modelContext.save()
                            case .review(let item):
                                deleteReview(item)
                            }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 84, for: .scrollContent)
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
