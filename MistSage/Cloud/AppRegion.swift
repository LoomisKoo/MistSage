import Foundation
import StoreKit

/// 数据分区：中国区商店 → cn，其余 → global；不同区的广场互不可见
enum AppRegion: String {
    case cn
    case global

    private static let cacheKey = "appRegion"

    /// 识别到的商店地区；从没识别成功过为 nil
    static var confirmed: AppRegion? {
        UserDefaults.standard.string(forKey: cacheKey).flatMap(AppRegion.init(rawValue:))
    }

    /// 浏览用：没识别过时按系统地区兜底。发帖必须用 confirmed
    static var current: AppRegion {
        confirmed ?? (Locale.current.region?.identifier == "CN" ? .cn : .global)
    }

    /// 读 App Store 商店地区（与上架区一致，比语言 / 时区可靠）；拿不到时沿用缓存
    static func refresh() async {
        guard let code = await Storefront.current?.countryCode else { return }
        let region: AppRegion = code == "CHN" ? .cn : .global
        UserDefaults.standard.set(region.rawValue, forKey: cacheKey)
    }
}
