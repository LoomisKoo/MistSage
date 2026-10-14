import Foundation
import SwiftData

enum DecisionKind: String, Codable, CaseIterable, Identifiable {
    case did = "做了"
    case skipped = "没做"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .did: return "checkmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        }
    }

    /// 做了 → 花钱；没做 → 省钱（由金额推断，不再单独选）
    var moneyLabel: String {
        switch self {
        case .did: return L("花了")
        case .skipped: return L("省了")
        }
    }
}

@Model
final class DecisionRecord {
    var id: UUID
    var title: String
    var kindRaw: String
    var topicRaw: String
    var money: Double
    var minutes: Int
    var note: String
    var createdAt: Date
    var ownerID: String = ""
    var needsUpload: Bool = true

    init(
        title: String,
        kind: DecisionKind,
        topic: DecisionTopic = .other,
        money: Double = 0,
        minutes: Int = 0,
        note: String = "",
        createdAt: Date = .now,
        ownerID: String = AccountSession.currentUserID
    ) {
        self.id = UUID()
        self.ownerID = ownerID
        self.title = title
        self.kindRaw = kind.rawValue
        self.topicRaw = topic.rawValue
        self.money = money
        self.minutes = minutes
        self.note = note
        self.createdAt = createdAt
    }

    var kind: DecisionKind {
        get {
            switch kindRaw {
            case DecisionKind.did.rawValue, "花了钱": return .did
            case DecisionKind.skipped.rawValue, "省了钱": return .skipped
            default: return .did
            }
        }
        set { kindRaw = newValue.rawValue }
    }

    var topic: DecisionTopic {
        get { DecisionTopic(rawValue: topicRaw) ?? .other }
        set { topicRaw = newValue.rawValue }
    }

    func timeCost(hourlyRate: Double) -> Double {
        guard hourlyRate > 0, minutes > 0 else { return 0 }
        return hourlyRate * Double(minutes) / 60.0
    }

    /// 做了 → 计入生活成本
    func recordedLivingCost(hourlyRate: Double) -> Double {
        kind == .did ? money + timeCost(hourlyRate: hourlyRate) : 0
    }

    /// 没做 → 计入省下
    func savedCost(hourlyRate: Double) -> Double {
        kind == .skipped ? money + timeCost(hourlyRate: hourlyRate) : 0
    }
}
