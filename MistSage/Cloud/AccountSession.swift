import Foundation

/// 当前账号：iCloud 身份 → Identity 表 → User 表的 recordName
enum AccountSession {
    private static let userIDKey = "session.currentUserID"
    private static let icloudKey = "session.icloudRecordName"
    private static let pendingDeletionKey = "session.pendingDeletion"
    private static let deletionUserKey = "session.deletionUserID"
    private static let deletionICloudKey = "session.deletionICloudID"

    /// User 表主键（随机 UUID）；未登录 iCloud 时为空
    static var currentUserID: String {
        get { UserDefaults.standard.string(forKey: userIDKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userIDKey) }
    }

    /// 上次识别到的 iCloud 用户 ID，用来发现账号切换
    static var icloudRecordName: String {
        get { UserDefaults.standard.string(forKey: icloudKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: icloudKey) }
    }

    /// 注销未完成：只清本地后中断，下次启动凭这两个 ID 继续删云端
    static var isPendingDeletion: Bool {
        get { UserDefaults.standard.bool(forKey: pendingDeletionKey) }
        set { UserDefaults.standard.set(newValue, forKey: pendingDeletionKey) }
    }

    static var deletionUserID: String {
        get { UserDefaults.standard.string(forKey: deletionUserKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: deletionUserKey) }
    }

    static var deletionICloudID: String {
        get { UserDefaults.standard.string(forKey: deletionICloudKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: deletionICloudKey) }
    }

    static var isSignedIn: Bool { !currentUserID.isEmpty }

    static func beginDeletion(userID: String, icloudID: String) {
        deletionUserID = userID
        deletionICloudID = icloudID
        isPendingDeletion = true
    }

    static func finishDeletion() {
        isPendingDeletion = false
        deletionUserID = ""
        deletionICloudID = ""
    }

    /// 登出本机会话；不清除注销进度（中断后要接着删）
    static func clear() {
        currentUserID = ""
        icloudRecordName = ""
    }
}

enum CloudConfig {
    static let containerID = "iCloud.com.tincom.mistsage"
}
