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

    var plazaLabel: String { localizedName }
}

enum AdvisorRank {
    /// 按「建议被采纳次数」递进：先入雾修行，再进仙阶
    static func title(adoptedCount: Int) -> String {
        switch adoptedCount {
        case 0: return L("过客")
        case 1, 2: return L("雾徒")
        case 3 ... 5: return L("雾士")
        case 6 ... 11: return L("雾灵")
        case 12 ... 19: return L("下仙")
        case 20 ... 29: return L("中仙")
        case 30 ... 44: return L("上仙")
        case 45 ... 64: return L("仙长")
        case 65 ... 99: return L("仙尊")
        default: return L("仙圣")
        }
    }
}
