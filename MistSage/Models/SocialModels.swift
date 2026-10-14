import Foundation
import SwiftData

/// 我拉黑的人；被拉黑者的帖子和建议在本机不再显示
@Model
final class BlockEntry {
    var blockerID: String
    var blockedID: String
    var createdAt: Date
    var needsUpload: Bool = true

    init(blockedID: String, blockerID: String = AccountSession.currentUserID) {
        self.blockerID = blockerID
        self.blockedID = blockedID
        self.createdAt = .now
    }
}

enum NoticeKind: String, CaseIterable {
    /// 有人给你的纠结提了建议
    case vote
    /// 你参与过的纠结有了最终决定
    case decided
}

/// 待发给别人的通知；上传成功后本地删除，对方靠 CloudKit 订阅收到推送
@Model
final class OutgoingNotice {
    var recipientID: String
    var kindRaw: String
    var reviewID: String
    var reviewTitle: String
    var createdAt: Date

    init(recipientID: String, kind: NoticeKind, reviewID: String, reviewTitle: String) {
        self.recipientID = recipientID
        self.kindRaw = kind.rawValue
        self.reviewID = reviewID
        self.reviewTitle = reviewTitle
        self.createdAt = .now
    }
}

enum ReportReason: String, CaseIterable, Identifiable {
    case harassment = "辱骂、骚扰或人身攻击"
    case sexual = "色情低俗"
    case spam = "广告营销"
    case illegal = "违法违规"
    case misinformation = "虚假或误导信息"
    case other = "其他"

    var id: String { rawValue }

    var cloudCode: String { String(describing: self) }
}

enum ReportTarget {
    case review(ReviewRequest)
    case vote(ReviewVote)
    case user(String)

    var typeCode: String {
        switch self {
        case .review: return "review"
        case .vote: return "vote"
        case .user: return "user"
        }
    }

    var recordName: String {
        switch self {
        case .review(let r): return r.recordName
        case .vote(let v): return v.recordName
        case .user(let id): return id
        }
    }

    var userID: String {
        switch self {
        case .review(let r): return r.authorID
        case .vote(let v): return v.voterID
        case .user(let id): return id
        }
    }
}
