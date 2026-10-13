import Foundation
import SwiftData
import UIKit

enum AssetKind: String, Codable, CaseIterable, Identifiable {
    case consumable = "消耗品"
    case durable = "耐用品"
    case keep = "收藏纪念"
    case other = "其他"

    var id: String { rawValue }

    /// 只有消耗品需要「存量」
    var tracksStock: Bool { self == .consumable }

    var hint: String {
        switch self {
        case .consumable: return "日用品、食品等会用完的东西，可记存量。"
        case .durable: return "电器、家具、衣服等耐用物，关注使用与闲置。"
        case .keep: return "纪念品、藏品等，一般不看存量。"
        case .other: return "不好归类时选这个。"
        }
    }
}

enum AssetStockStatus: String, Codable, CaseIterable, Identifiable {
    case plenty = "充足"
    case low = "不多了"
    case empty = "见底"

    var id: String { rawValue }

    var hint: String {
        switch self {
        case .plenty: return "还很多，暂时不用补"
        case .low: return "快用完了"
        case .empty: return "基本耗尽，该补或该丢"
        }
    }
}

@Model
final class AssetItem {
    var id: UUID
    var name: String
    var summary: String
    /// 价值（原购入价语义，展示为「价值」）
    var price: Double
    var estimatedUses: Int
    /// 累计用过几次：用来算「单次成本」「平均几天用一次」
    var useCount: Int
    var statusRaw: String
    var kindRaw: String
    var iconName: String
    /// 本地照片文件名（Documents/AssetPhotos/）
    var photoFileName: String
    var isPublic: Bool
    var purchasedAt: Date
    var lastUsedAt: Date?
    var createdAt: Date

    init(
        name: String,
        summary: String = "",
        price: Double = 0,
        estimatedUses: Int = 0,
        useCount: Int = 0,
        status: AssetStockStatus = .plenty,
        kind: AssetKind = .durable,
        iconName: String = AssetIconOption.cube.rawValue,
        photoFileName: String = "",
        isPublic: Bool = false,
        purchasedAt: Date = .now,
        lastUsedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.summary = summary
        self.price = price
        self.estimatedUses = estimatedUses
        self.useCount = useCount
        self.statusRaw = status.rawValue
        self.kindRaw = kind.rawValue
        self.iconName = iconName
        self.photoFileName = photoFileName
        self.isPublic = isPublic
        self.purchasedAt = purchasedAt
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }

    var status: AssetStockStatus {
        get { AssetStockStatus(rawValue: statusRaw) ?? .plenty }
        set { statusRaw = newValue.rawValue }
    }

    var kind: AssetKind {
        get { AssetKind(rawValue: kindRaw) ?? .durable }
        set { kindRaw = newValue.rawValue }
    }

    var resolvedIcon: String {
        iconName.isEmpty ? AssetIconOption.cube.rawValue : iconName
    }

    var hasPhoto: Bool { !photoFileName.isEmpty }

    var photoImage: UIImage? {
        AssetPhotoStore.load(fileName: photoFileName)
    }

    /// 入手至今天数
    var ownedDays: Int {
        max(Calendar.current.dateComponents([.day], from: purchasedAt, to: .now).day ?? 0, 0)
    }

    var idleDays: Int {
        let ref = lastUsedAt ?? purchasedAt
        return Calendar.current.dateComponents([.day], from: ref, to: .now).day ?? 0
    }

    var isIdle: Bool {
        if useCount == 0 { return idleDays >= 30 }
        return idleDays >= 60
    }

    var needsRestock: Bool {
        kind.tracksStock && (status == .low || status == .empty)
    }

    /// 单次使用成本（价值 ÷ 次数）；0 次时用「若只用 1 次」口径
    var costPerUse: Double? {
        guard price > 0 else { return nil }
        let n = max(useCount, 1)
        return price / Double(n)
    }

    /// 平均多少天用一次（入手天数 ÷ 次数）
    var avgDaysPerUse: Double? {
        guard useCount > 0, ownedDays > 0 else { return nil }
        return Double(ownedDays) / Double(useCount)
    }

    var utilizationHint: String {
        if useCount <= 0 {
            return "还没记过使用。点「用了一次」后，可算单次成本和平均使用间隔。"
        }
        var parts: [String] = ["累计用过 \(useCount) 次"]
        if let avg = avgDaysPerUse {
            parts.append(String(format: "平均 %.0f 天用一次", avg))
        }
        if let cpu = costPerUse {
            parts.append("目前单次约 \(Theme.money(cpu))")
        }
        return parts.joined(separator: " · ")
    }

    func markUsed() {
        useCount += 1
        lastUsedAt = .now
    }

    func setPhoto(_ image: UIImage?) {
        if let image {
            let name = photoFileName.isEmpty ? "\(id.uuidString).jpg" : photoFileName
            if AssetPhotoStore.save(image, fileName: name) {
                photoFileName = name
            }
        } else {
            AssetPhotoStore.delete(fileName: photoFileName)
            photoFileName = ""
        }
    }
}

enum AssetPhotoStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AssetPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func url(fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func save(_ image: UIImage, fileName: String) -> Bool {
        let normalized = image.normalizedUpOrientation()
        guard let data = normalized.jpegData(compressionQuality: 0.82) else { return false }
        do {
            try data.write(to: url(fileName: fileName), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func load(fileName: String) -> UIImage? {
        guard !fileName.isEmpty,
              let data = try? Data(contentsOf: url(fileName: fileName))
        else { return nil }
        return UIImage(data: data)
    }

    static func delete(fileName: String) {
        guard !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(fileName: fileName))
    }
}

private extension UIImage {
    func normalizedUpOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
