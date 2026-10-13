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
}

enum ReviewSuggestion: String, Codable, CaseIterable, Identifiable {
    case doIt = "建议做"
    case wait = "缓一缓"
    case skip = "建议不做"

    var id: String { rawValue }

    /// 与最终裁定是否一致（缓一缓不算采纳）
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
    /// 兼容旧库；UI 已去掉「倾向」
    var leaningRaw: String
    var statusRaw: String
    var topicRaw: String
    var createdAt: Date
    var coolUntil: Date?
    var authorName: String
    var isMine: Bool
    var isPublicOnPlaza: Bool
    var isDemo: Bool

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
        authorName: String = "我",
        isMine: Bool = true,
        isPublicOnPlaza: Bool = true,
        isDemo: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.money = money
        self.minutes = minutes
        self.reason = reason
        self.alternative = alternative
        self.constraints = constraints
        self.leaningRaw = ""
        self.statusRaw = status.rawValue
        self.topicRaw = topic.rawValue
        self.createdAt = createdAt
        self.coolUntil = Calendar.current.date(byAdding: .hour, value: coolHours, to: createdAt)
        self.authorName = authorName
        self.isMine = isMine
        self.isPublicOnPlaza = isPublicOnPlaza
        self.isDemo = isDemo
    }

    var status: ReviewStatus {
        get { ReviewStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var topic: DecisionTopic {
        get { DecisionTopic(rawValue: topicRaw) ?? .other }
        set { topicRaw = newValue.rawValue }
    }

    var isCooling: Bool {
        guard let coolUntil else { return false }
        return Date() < coolUntil && (status == .cooling || status == .pending)
    }

    var isClosed: Bool { status.isFinal }

    func timeCost(hourlyRate: Double) -> Double {
        guard hourlyRate > 0, minutes > 0 else { return 0 }
        return hourlyRate * Double(minutes) / 60.0
    }

    /// 发起人裁定：锁定结果，仍留在广场供他人参考
    func finalize(as newStatus: ReviewStatus) {
        guard newStatus.isFinal, !isClosed else { return }
        status = newStatus
        isPublicOnPlaza = true
    }
}

@Model
final class ReviewVote {
    var id: UUID
    var reviewId: UUID
    var suggestionRaw: String
    var comment: String
    var createdAt: Date
    var isMine: Bool
    var authorName: String

    init(
        reviewId: UUID,
        suggestion: ReviewSuggestion,
        comment: String = "",
        isMine: Bool = true,
        authorName: String = "我",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.reviewId = reviewId
        self.suggestionRaw = suggestion.rawValue
        self.comment = comment
        self.isMine = isMine
        self.authorName = authorName
        self.createdAt = createdAt
    }

    var suggestion: ReviewSuggestion {
        get { ReviewSuggestion(rawValue: suggestionRaw) ?? .wait }
        set { suggestionRaw = newValue.rawValue }
    }

    var displayName: String {
        if isMine { return "我" }
        return authorName.isEmpty ? "一位路过的人" : authorName
    }

    func isAdopted(by review: ReviewRequest) -> Bool {
        suggestion.matchesFinal(review.status)
    }
}
