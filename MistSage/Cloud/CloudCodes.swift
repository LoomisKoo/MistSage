import Foundation

/// 枚举在云端存英文代码，不存中文文案，改文案不影响数据
protocol CloudCoded: CaseIterable {
    var cloudCode: String { get }
}

extension CloudCoded {
    var cloudCode: String { String(describing: self) }

    static func fromCloud(_ code: String?) -> Self? {
        guard let code else { return nil }
        return allCases.first { $0.cloudCode == code }
    }
}

extension DecisionKind: CloudCoded {}
extension DecisionTopic: CloudCoded {}
extension ReviewStatus: CloudCoded {}
extension ReviewSuggestion: CloudCoded {}
extension AssetKind: CloudCoded {}
extension AssetStockStatus: CloudCoded {}
extension TimeCostAssist: CloudCoded {}

extension ProfileGender: CloudCoded {
    var cloudCode: String {
        switch self {
        case .private_: return "hidden"
        case .male: return "male"
        case .female: return "female"
        }
    }
}

enum CloudType {
    static let identity = "Identity"
    static let user = "User"
    static let decision = "Decision"
    static let review = "Review"
    static let vote = "Vote"
    static let asset = "Asset"
    static let image = "Image"
    static let block = "Block"
    static let report = "Report"
    static let notice = "Notice"
}
