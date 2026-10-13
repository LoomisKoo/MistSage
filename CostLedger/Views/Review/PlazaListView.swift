import SwiftUI
import SwiftData

struct PlazaListView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \ReviewRequest.createdAt, order: .reverse) private var reviews: [ReviewRequest]
    @State private var topicFilter: DecisionTopic? = nil

    private var plazaReviews: [ReviewRequest] {
        reviews.filter(\.isPublicOnPlaza)
    }

    private var displayed: [ReviewRequest] {
        guard let topicFilter else { return plazaReviews }
        return plazaReviews.filter { $0.topic == topicFilter }
    }

    var body: some View {
        VStack(spacing: 0) {
            topicTabs

            Group {
                if displayed.isEmpty {
                    EmptyHint(
                        systemImage: "square.grid.2x2",
                        title: topicFilter == nil ? "广场还空着" : "这类暂时没有",
                        message: "别人的纠结会出现在这里；你也可以给出建议。"
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(displayed, id: \.id) { item in
                                NavigationLink {
                                    ReviewDetailView(item: item)
                                } label: {
                                    ReviewRow(
                                        item: item,
                                        hourlyRate: settings.hourlyRate,
                                        showAuthor: true
                                    )
                                }
                                .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .padding(.bottom, 88)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AtmosphereBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("广场")
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    private var topicTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(DecisionTopic.plazaTabs.enumerated()), id: \.offset) { _, topic in
                    let selected = topicFilter == topic
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) { topicFilter = topic }
                    } label: {
                        Text(topic?.plazaLabel ?? "全部")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected ? Color.white : Theme.inkSoft)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selected ? Theme.accent : Theme.paperDeep)
                            )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}
