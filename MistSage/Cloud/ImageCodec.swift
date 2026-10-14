import UIKit
import CloudKit

/// 上传前压缩：原图限制长边，另出一张缩略图给列表用
enum ImageCodec {
    static let avatarMaxSide: CGFloat = 512
    static let avatarThumbSide: CGFloat = 160
    static let assetMaxSide: CGFloat = 1600
    static let assetThumbSide: CGFloat = 400

    static func jpeg(_ image: UIImage, maxSide: CGFloat, quality: CGFloat = 0.8) -> (data: Data, size: CGSize)? {
        let resized = resize(image, maxSide: maxSide)
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        return (data, CGSize(width: resized.size.width * resized.scale, height: resized.size.height * resized.scale))
    }

    static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let pixelW = image.size.width * image.scale
        let pixelH = image.size.height * image.scale
        let longest = max(pixelW, pixelH)
        let ratio = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(width: (pixelW * ratio).rounded(), height: (pixelH * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// CKAsset 只接受文件 URL
    static func asset(from data: Data) throws -> CKAsset {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ck_\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return CKAsset(fileURL: url)
    }

    static func data(of asset: CKAsset?) -> Data? {
        guard let url = asset?.fileURL else { return nil }
        return try? Data(contentsOf: url)
    }
}
