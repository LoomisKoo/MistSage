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
        case .consumable: return L("日用品、食品等会用完的东西，可记存量。")
        case .durable: return L("电器、家具、衣服等耐用物，关注使用与闲置。")
        case .keep: return L("纪念品、藏品等，一般不看存量。")
        case .other: return L("不好归类时选这个。")
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
        case .plenty: return L("还很多，暂时不用补")
        case .low: return L("快用完了")
        case .empty: return L("基本耗尽，该补或该丢")
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
    /// 本地照片文件名（Documents/AssetPhotos/），第一张为封面
    var photoFileNames: [String] = []
    /// 与 photoFileNames 一一对应的云端 Image recordName；未上传为空串
    var photoImageIDs: [String] = []
    var isPublic: Bool
    var purchasedAt: Date
    var lastUsedAt: Date?
    var createdAt: Date
    var ownerID: String = ""
    var photosNeedUpload: Bool = false
    var needsUpload: Bool = true

    init(
        name: String,
        summary: String = "",
        price: Double = 0,
        estimatedUses: Int = 0,
        useCount: Int = 0,
        status: AssetStockStatus = .plenty,
        kind: AssetKind = .durable,
        iconName: String = AssetIconOption.cube.rawValue,
        isPublic: Bool = false,
        purchasedAt: Date = .now,
        lastUsedAt: Date? = nil,
        createdAt: Date = .now,
        ownerID: String = AccountSession.currentUserID
    ) {
        self.id = UUID()
        self.ownerID = ownerID
        self.name = name
        self.summary = summary
        self.price = price
        self.estimatedUses = estimatedUses
        self.useCount = useCount
        self.statusRaw = status.rawValue
        self.kindRaw = kind.rawValue
        self.iconName = iconName
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

    var hasPhoto: Bool { !photoFileNames.isEmpty }

    /// 封面
    var photoImage: UIImage? {
        photoFileNames.first.flatMap(AssetPhotoStore.load(fileName:))
    }

    var photoImages: [UIImage] {
        photoFileNames.compactMap(AssetPhotoStore.load(fileName:))
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
            return L("还没记过使用。点「用了一次」后，可算单次成本和平均使用间隔。")
        }
        var parts: [String] = [L("累计用过 \(useCount) 次")]
        if let avg = avgDaysPerUse {
            parts.append(L("平均 \(Int(avg.rounded())) 天用一次"))
        }
        if let cpu = costPerUse {
            parts.append(L("目前单次约 \(Theme.money(cpu))"))
        }
        return parts.joined(separator: " · ")
    }

    func markUsed() {
        useCount += 1
        lastUsedAt = .now
        needsUpload = true
    }

    /// 用编辑后的照片列表替换现有照片；返回被移除的云端图片 ID
    @discardableResult
    func applyPhotos(_ drafts: [AssetPhotoDraft]) -> [String] {
        var names: [String] = []
        var ids: [String] = []
        for draft in drafts {
            switch draft {
            case .existing(let fileName, let imageID):
                names.append(fileName)
                ids.append(imageID)
            case .new(_, let image):
                let fileName = "\(id.uuidString)_\(UUID().uuidString).jpg"
                if AssetPhotoStore.save(image, fileName: fileName) {
                    names.append(fileName)
                    ids.append("")
                }
            }
        }

        for old in photoFileNames where !names.contains(old) {
            AssetPhotoStore.delete(fileName: old)
        }
        let removedIDs = photoImageIDs.filter { !$0.isEmpty && !ids.contains($0) }

        if names != photoFileNames || ids != photoImageIDs {
            photoFileNames = names
            photoImageIDs = ids
            photosNeedUpload = true
        }
        return removedIDs
    }

    var photoDrafts: [AssetPhotoDraft] {
        zip(photoFileNames, photoImageIDs.padded(to: photoFileNames.count)).map {
            .existing(fileName: $0.0, imageID: $0.1)
        }
    }
}

enum AssetPhotoDraft: Identifiable {
    case existing(fileName: String, imageID: String)
    case new(id: UUID, image: UIImage)

    static let maxCount = 9

    var id: String {
        switch self {
        case .existing(let fileName, _): return fileName
        case .new(let id, _): return id.uuidString
        }
    }

    var image: UIImage? {
        switch self {
        case .existing(let fileName, _): return AssetPhotoStore.load(fileName: fileName)
        case .new(_, let image): return image
        }
    }
}

private extension Array where Element == String {
    func padded(to count: Int) -> [String] {
        self.count >= count ? Array(prefix(count)) : self + Array(repeating: "", count: count - self.count)
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
        return save(data: data, fileName: fileName)
    }

    static func save(data: Data, fileName: String) -> Bool {
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

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
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
