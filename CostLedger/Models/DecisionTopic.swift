import Foundation

/// 决策 / 征求建议的事项类型（广场可筛选）
enum DecisionTopic: String, Codable, CaseIterable, Identifiable {
    case shopping = "购物"
    case food = "吃喝"
    case learn = "学习"
    case travel = "出行"
    case digital = "数码"
    case other = "其他"

    var id: String { rawValue }

    /// 广场顶部：全部 + 各类型
    static var plazaTabs: [DecisionTopic?] { [nil] + allCases.map { Optional($0) } }

    var plazaLabel: String { rawValue }
}

enum AdvisorRank {
    /// 按「被采纳次数」给称号（比「初级建议员」更口语）
    static func title(adoptedCount: Int) -> String {
        switch adoptedCount {
        case 0: return "刚来旁听"
        case 1, 2: return "靠谱参谋"
        case 3 ... 9: return "冷静搭子"
        default: return "代价顾问"
        }
    }
}
