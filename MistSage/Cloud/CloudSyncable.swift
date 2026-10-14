import CloudKit
import SwiftData

/// 本地删除后、尚未同步到云端的记录
@Model
final class PendingDeletion {
    var recordName: String
    var recordType: String
    var createdAt: Date

    init(recordName: String, recordType: String) {
        self.recordName = recordName
        self.recordType = recordType
        self.createdAt = .now
    }
}

protocol CloudSyncable: PersistentModel {
    static var recordType: String { get }
    var recordName: String { get }
    var needsUpload: Bool { get set }
    func fill(_ record: CKRecord)
    func apply(_ record: CKRecord)
    static func make(from record: CKRecord) -> Self?
}

extension DecisionRecord: CloudSyncable {
    static var recordType: String { CloudType.decision }
    var recordName: String { id.uuidString }
}

extension ReviewRequest: CloudSyncable {
    static var recordType: String { CloudType.review }
    var recordName: String { id.uuidString }
}

extension ReviewVote: CloudSyncable {
    static var recordType: String { CloudType.vote }
    /// 同一人对同一帖只能有一条建议
    var recordName: String { Self.recordName(reviewID: reviewId, voterID: voterID) }

    static func recordName(reviewID: UUID, voterID: String) -> String {
        "\(reviewID.uuidString)_\(voterID)"
    }
}

extension AssetItem: CloudSyncable {
    static var recordType: String { CloudType.asset }
    var recordName: String { id.uuidString }
}

extension BlockEntry: CloudSyncable {
    static var recordType: String { CloudType.block }
    var recordName: String { Self.recordName(blockerID: blockerID, blockedID: blockedID) }

    static func recordName(blockerID: String, blockedID: String) -> String {
        "\(blockerID)_\(blockedID)"
    }
}

extension ModelContext {
    /// 删除本地记录，并登记待删，下次同步时删掉云端
    func deleteSynced<T: CloudSyncable>(_ model: T) {
        insert(PendingDeletion(recordName: model.recordName, recordType: T.recordType))
        if let asset = model as? AssetItem {
            for imageID in asset.photoImageIDs where !imageID.isEmpty {
                insert(PendingDeletion(recordName: imageID, recordType: CloudType.image))
            }
            asset.photoFileNames.forEach(AssetPhotoStore.delete(fileName:))
        }
        delete(model)
    }

    /// 更新资产照片，被移除的云端图片登记待删
    func applyPhotos(_ drafts: [AssetPhotoDraft], to asset: AssetItem) {
        for imageID in asset.applyPhotos(drafts) {
            insert(PendingDeletion(recordName: imageID, recordType: CloudType.image))
        }
    }
}
