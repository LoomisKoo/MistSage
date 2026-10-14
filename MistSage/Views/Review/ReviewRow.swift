import SwiftUI

struct ReviewRow: View {
    let item: ReviewRequest
    var hourlyRate: Double = 0
    var showAuthor: Bool = false
    @ObservedObject private var users = UserDirectory.shared

    var body: some View {
        SoftPanel(padding: 16) {
            if showAuthor {
                plazaLayout
            } else {
                mineLayout
            }
        }
    }

    private var plazaLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !item.reason.isEmpty {
                Text(item.reason)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Text(users.name(for: item.authorID))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accentDeep)
                Text(item.topic.localizedName)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                if item.money > 0 {
                    Text("·")
                        .foregroundStyle(Theme.placeholder)
                    Text(Theme.money(item.money))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                // 广场：未决不展示「冷静中」；已决才标结果，方便别人参考
                if item.isClosed {
                    statusBadge
                }
            }
        }
    }

    /// 待决列表：标题+正文在上，标签与时间在底同一行
    private var mineLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !item.reason.isEmpty {
                Text(item.reason)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                statusBadge
                Text(item.topic.localizedName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.paperDeep))
                if item.money > 0 {
                    Text(Theme.money(item.money))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                Text(item.createdAt.appFormatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var statusBadge: some View {
        Text(item.status.localizedName)
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusFg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(statusBg))
    }

    private var statusFg: Color {
        switch item.status {
        case .decidedSkip: return Theme.accentDeep
        case .decidedDo: return Theme.warn
        default: return Theme.inkSoft
        }
    }

    private var statusBg: Color {
        switch item.status {
        case .decidedSkip: return Theme.accentSoft
        case .decidedDo: return Theme.warnSoft
        default: return Theme.paperDeep
        }
    }
}
