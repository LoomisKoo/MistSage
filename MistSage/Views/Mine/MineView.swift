import SwiftUI
import SwiftData

struct MineView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query private var decisions: [DecisionRecord]
    @Query private var assets: [AssetItem]
    @Query private var reviews: [ReviewRequest]
    @Query private var votes: [ReviewVote]
    @ObservedObject private var cloud = CloudSync.shared
    @State private var showEditProfile = false

    /// 本月：已决里「省下」的记录 + 征求建议里拍板「不做」的金额与时间
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

    private var mineReviews: [ReviewRequest] {
        reviews.filter(\.isMine)
    }

    /// 冷静中 / 征求中，尚未做最终决定
    private var openCount: Int {
        mineReviews.filter { $0.status == .pending || $0.status == .cooling }.count
    }

    /// 已做出做 / 不做的征求建议
    private var closedReviewCount: Int {
        mineReviews.filter(\.isClosed).count
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
                if let notice = cloudNotice {
                    SoftPanel(padding: 14) {
                        Label(notice, systemImage: "icloud.slash")
                            .font(.subheadline)
                            .foregroundStyle(Theme.warn)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                profileHeader

                MetricHero(
                    eyebrow: "本月省下",
                    value: Theme.money(monthSaved),
                    footnote: L("含「决定不做」的征求建议，以及已决里记为省下的钱与时间。"),
                    accent: Theme.accentDeep,
                    softFill: Theme.surface
                )

                if adoptedCount > 0 {
                    MetricHero(
                        eyebrow: "建议被采纳",
                        value: "\(adoptedCount)",
                        footnote: helpedOthersSaved > 0
                            ? L("对方最终决定与你一致；其中「建议不做」约帮人省下 \(Theme.money(helpedOthersSaved))。")
                            : L("对方最终决定与你的建议一致。"),
                        accent: Theme.accentDeep,
                        softFill: Theme.surface
                    )
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    summaryCard("进行中", "\(openCount)", L("还没做最终决定"))
                    summaryCard("已拍板", "\(closedReviewCount)", L("征求建议已有结论"))
                    summaryCard("直接记录", "\(decisions.count)", L("决策里「已决」的笔数"))
                    summaryCard(
                        "资产",
                        "\(assets.count)",
                        idleCount > 0
                            ? L("闲置 \(idleCount) 件")
                            : L("登记过的物品")
                    )
                }

                SoftPanel(padding: 4) {
                    NavigationLink {
                        ParticipatedReviewsView()
                    } label: {
                        mineLink(
                            icon: "lightbulb.fill",
                            title: "我参与的建议",
                            subtitle: adoptedCount > 0
                                ? L("被采纳 \(adoptedCount) 条 · 点进查看")
                                : L("你在广场给过建议的单")
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(AtmosphereBackground())
        .sheet(isPresented: $showEditProfile) {
            NavigationStack { EditProfileView() }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var cloudNotice: String? {
        if AccountSession.isPendingDeletion {
            return cloud.lastError ?? L("账号清理尚未完成，联网后会自动继续")
        }
        switch cloud.state {
        case .checking, .available:
            return cloud.lastError
        case .noAccount:
            return L("未登录 iCloud：只能浏览广场。请在系统「设置」中登录 iCloud 后再记录。")
        case .unavailable(let reason):
            return reason
        }
    }

    private func mineLink(icon: String, title: LocalizedStringKey, subtitle: String) -> some View {
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
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.accentSoft)
                            )
                        if let gender = settings.gender.publicLabel {
                            Text(gender)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.inkSoft)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Theme.paperDeep)
                                )
                        }
                    }
                }
                Spacer(minLength: 0)
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

    private func summaryCard(_ title: LocalizedStringKey, _ value: String, _ footnote: String) -> some View {
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
