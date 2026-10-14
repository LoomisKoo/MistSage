import Foundation
import SwiftData

/// 云端 User 表的本地缓存（只读镜像，不在本地修改别人的资料）
@Model
final class UserProfile {
    @Attribute(.unique) var id: String
    var nickname: String
    var genderCode: String
    /// active / deleted；注销中的账号在广场里不再显示
    var stateCode: String = "active"
    var avatarImageID: String
    @Attribute(.externalStorage) var avatarData: Data?
    var updatedAt: Date

    init(id: String, nickname: String = "", genderCode: String = "", avatarImageID: String = "") {
        self.id = id
        self.nickname = nickname
        self.genderCode = genderCode
        self.stateCode = "active"
        self.avatarImageID = avatarImageID
        self.updatedAt = .now
    }

    var isDeleted: Bool { stateCode == "deleted" }
}
