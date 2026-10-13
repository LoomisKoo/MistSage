import SwiftUI
import SwiftData

struct MineView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query private var decisions: [DecisionRecord]
    @Query private var assets: [AssetItem]
    @Query private var reviews: [ReviewRequest]
    @Query private var votes: [ReviewVote]
    @State private var showEditProfile = false
    @State private var showSettings = false

    private var monthSaved: Double {
        let cal = Calendar.current
        let now = Date()
        let fromRecords = decisions
            .filter { cal.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.savedCost(hourlyRate: settings.hourlyRate) }
        let fromReviews = reviews
            .filter {
                $0.isMine
                    && cal.isDate($0.createdAt, equalTo: now, toGranularity: .month)
                    && $0.status == .decidedSkip
            }
            .reduce(0) { $0 + $1.money + $1.timeCost(hourlyRate: settings.hourlyRate) }
        return fromRecords + fromReviews
    }

    private var monthLiving: Double {
        let cal = Calendar.current
        let now = Date()
        return decisions
            .filter { cal.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.recordedLivingCost(hourlyRate: settings.hourlyRate) }
    }

    private var mineReviews: [ReviewRequest] {
        reviews.filter(\.isMine)
    }

    private var decidedReviews: Int {
        mineReviews.filter(\.isClosed).count
    }

    private var skipRate: Double {
        guard decidedReviews > 0 else { return 0 }
        let skips = mineReviews.filter { $0.status == .decidedSkip }.count
        return Double(skips) / Double(decidedReviews)
    }

    private var idleCount: Int { assets.filter(\.isIdle).count }

    /// 我的建议被对方最终决定采纳
    private var myAdoptedVotes: [(ReviewVote, ReviewRequest)] {
        let mineVotes = votes.filter(\.isMine)
        var result: [(ReviewVote, ReviewRequest)] = []
        for vote in mineVotes {
            guard let review = reviews.first(where: { $0.id == vote.reviewId }),
                  !review.isMine,
                  vote.isAdopted(by: review)
            else { continue }
            result.append((vote, review))
        }
        return result
    }

    private var adoptedCount: Int { myAdoptedVotes.count }

    /// 对方采纳「建议不做」时，记入帮助他人省下的钱
    private var helpedOthersSaved: Double {
        myAdoptedVotes
            .filter { $0.1.status == .decidedSkip && $0.0.suggestion == .skip }
            .reduce(0) { $0 + $1.1.money + $1.1.timeCost(hourlyRate: settings.hourlyRate) }
    }

    private var advisorTitle: String {
        AdvisorRank.title(adoptedCount: adoptedCount)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                profileHeader

                if helpedOthersSaved > 0 || adoptedCount > 0 {
                    MetricHero(
                        eyebrow: "帮助他人省下",
                        value: Theme.money(helpedOthersSaved),
                        footnote: adoptedCount > 0
                            ? "有 \(adoptedCount) 条建议被对方采纳（最终决定与你一致）。"
                            : "对方采纳你的「建议不做」后会计入这里。",
                        accent: Theme.accentDeep,
                        softFill: Theme.surface
                    )
                }

                MetricHero(
                    eyebrow: "本月自己省下的总代价",
                    value: Theme.money(monthSaved),
                    footnote: "待决「决定不做」+ 已决记录里省下的钱与时间。",
                    accent: Theme.accentDeep,
                    softFill: Theme.surface
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    summaryCard("待决", "\(mineReviews.count)", "进行中 \(openCount)")
                    summaryCard("已决", "\(decisions.count)", "本月生活成本 \(Theme.money(monthLiving))")
                    summaryCard("资产", "\(assets.count)", idleCount > 0 ? "闲置 \(idleCount)" : "暂无闲置")
                    summaryCard("不做率", skipRateText, "已裁定 \(decidedReviews) 单")
                }

                SoftPanel(padding: 4) {
                    NavigationLink {
                        ParticipatedReviewsView()
                    } label: {
                        mineLink(
                            icon: "lightbulb.fill",
                            title: "我参与的建议",
                            subtitle: adoptedCount > 0
                                ? "被采纳 \(adoptedCount) 条 · 点进查看"
                                : "你在广场给过建议的单"
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(AtmosphereBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("我的")
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("设置")
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack { EditProfileView() }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var openCount: Int {
        mineReviews.filter { $0.status == .pending || $0.status == .cooling }.count
    }

    private func mineLink(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private var skipRateText: String {
        guard decidedReviews > 0 else { return "—" }
        return String(format: "%.0f%%", skipRate * 100)
    }

    private var profileHeader: some View {
        Button { showEditProfile = true } label: {
            HStack(spacing: 14) {
                avatarView
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.displayName)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 6) {
                        Text(advisorTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accentDeep)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.accentSoft))
                        if let gender = settings.gender.publicLabel {
                            Text(gender)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.inkSoft)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.paperDeep))
                        }
                    }
                    Text("点击编辑资料")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
            )
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
    }

    @ViewBuilder
    private var avatarView: some View {
        if let image = settings.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
        } else {
            Text(settings.avatarInitial)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.accent))
        }
    }

    private func summaryCard(_ title: String, _ value: String, _ footnote: String) -> some View {
        SoftPanel(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
