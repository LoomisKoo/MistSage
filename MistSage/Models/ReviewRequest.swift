import Foundation
import SwiftData

enum ReviewStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "待建议"
    case cooling = "冷静中"
    case decidedDo = "已决定做"
    case decidedSkip = "已决定不做"

    var id: String { rawValue }

    var isFinal: Bool {
        self == .decidedDo || self == .decidedSkip
    }

    /// 列表标签用的短文案
    var badgeName: String {
        switch self {
        case .decidedDo: return L("已拍板 · 做")
        case .decidedSkip: return L("已拍板 · 不做")
        case .pending: return L("待拍板")
        case .cooling: return localizedName
        }
    }
}

enum CoolOffPeriod: Int, CaseIterable, Identifiable {
    case hour1 = 1
    case hour6 = 6
    case day1 = 24
    case day3 = 72
    case day7 = 168
    case day30 = 720

    var id: Int { rawValue }
    var hours: Int { rawValue }

    var label: String { Theme.remaining(minutes: hours * 60) }

    /// 按金额推荐；30 天只能手动选
    static func suggested(for money: Double) -> CoolOffPeriod {
        let t: [Double] = Theme.usesCNY ? [100, 500, 3000, 10000] : [15, 70, 400, 1500]
        guard money > 0 else { return .day1 }
        if money < t[0] { return .hour1 }
        if money < t[1] { return .hour6 }
        if money < t[2] { return .day1 }
        if money < t[3] { return .day3 }
        return .day7
    }
}

enum ReviewSuggestion: String, Codable, CaseIterable, Identifiable {
    case doIt = "建议做"
    case wait = "缓一缓"
    case skip = "建议不做"

    var id: String { rawValue }

    /// 列表里的短文案：不加「建议」前缀
    var shortName: String {
        switch self {
        case .doIt: return L("做")
        case .wait: return L("缓一缓")
        case .skip: return L("不做")
        }
    }

    /// 新建议只能二选一；wait 仅为兼容旧数据保留
    static let selectable: [ReviewSuggestion] = [.doIt, .skip]

    /// 与最终拍板是否一致（缓一缓不算采纳）
    func matchesFinal(_ status: ReviewStatus) -> Bool {
        switch status {
        case .decidedDo: return self == .doIt
        case .decidedSkip: return self == .skip
        default: return false
        }
    }
}

@Model
final class ReviewRequest {
    var id: UUID
    var title: String
    var money: Double
    var minutes: Int
    var reason: String
    var alternative: String
    var constraints: String
    var statusRaw: String
    var topicRaw: String
    var createdAt: Date
    var coolUntil: Date?
    var decidedAt: Date?
    /// 作者在用户表里的 ID；昵称等资料一律从用户表查
    var authorID: String = ""
    var isPublicOnPlaza: Bool
    /// 发布时所在分区（AppRegion），之后不随用户换区而变
    var region: String = "global"
    var needsUpload: Bool = true

    init(
        title: String,
        money: Double = 0,
        minutes: Int = 0,
        reason: String = "",
        alternative: String = "",
        constraints: String = "",
        status: ReviewStatus = .cooling,
        topic: DecisionTopic = .other,
        createdAt: Date = .now,
        coolHours: Int = 24,
        authorID: String = AccountSession.currentUserID,
        isPublicOnPlaza: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.money = money
        self.minutes = minutes
        self.reason = reason
        self.alternative = alternative
        self.constraints = constraints
        self.statusRaw = status.rawValue
        self.topicRaw = topic.rawValue
        self.createdAt = createdAt
        self.coolUntil = Calendar.current.date(byAdding: .hour, value: coolHours, to: createdAt)
        self.authorID = authorID
        self.isPublicOnPlaza = isPublicOnPlaza
        self.region = AppRegion.current.rawValue
    }

    /// 冷静期过了自动视为「待建议」（别人不能改作者的记录，所以不写回）
    var status: ReviewStatus {
        get {
            let raw = ReviewStatus(rawValue: statusRaw) ?? .pending
            if raw == .cooling, let coolUntil, Date() >= coolUntil { return .pending }
            return raw
        }
        set { statusRaw = newValue.rawValue }
    }

    var topic: DecisionTopic {
        get { DecisionTopic(rawValue: topicRaw) ?? .other }
        set { topicRaw = newValue.rawValue }
    }

    var isMine: Bool {
        !authorID.isEmpty && authorID == AccountSession.currentUserID
    }

    var isCooling: Bool {
        guard let coolUntil else { return false }
        return Date() < coolUntil && (status == .cooling || status == .pending)
    }

    var isClosed: Bool { status.isFinal }

    /// 冷静期结束 7 天还没拍板
    var isOverdue: Bool {
        guard !isClosed, let coolUntil else { return false }
        return Date() >= coolUntil.addingTimeInterval(7 * 24 * 3600)
    }

    func timeCost(hourlyRate: Double) -> Double {
        guard hourlyRate > 0, minutes > 0 else { return 0 }
        return hourlyRate * Double(minutes) / 60.0
    }

    /// 发起人拍板：锁定结果，仍留在广场供他人参考
    func finalize(as newStatus: ReviewStatus) {
        guard newStatus.isFinal, !isClosed else { return }
        status = newStatus
        decidedAt = .now
        isPublicOnPlaza = true
        needsUpload = true
    }
}

@Model
final class ReviewVote {
    var id: UUID
    var reviewId: UUID
    var voterID: String = ""
    var suggestionRaw: String
    var comment: String
    var createdAt: Date
    var needsUpload: Bool = true

    init(
        reviewId: UUID,
        suggestion: ReviewSuggestion,
        comment: String = "",
        voterID: String = AccountSession.currentUserID,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.reviewId = reviewId
        self.suggestionRaw = suggestion.rawValue
        self.comment = comment
        self.voterID = voterID
        self.createdAt = createdAt
    }

    var suggestion: ReviewSuggestion {
        get { ReviewSuggestion(rawValue: suggestionRaw) ?? .wait }
        set { suggestionRaw = newValue.rawValue }
    }

    var isMine: Bool {
        !voterID.isEmpty && voterID == AccountSession.currentUserID
    }

    func isAdopted(by review: ReviewRequest) -> Bool {
        suggestion.matchesFinal(review.status)
    }
}
