import SwiftUI
import SwiftData

/// 按用户 ID 查昵称、头像、性别；数据来自 User 表缓存，本人则用本机最新资料
@MainActor
final class UserDirectory: ObservableObject {
    static let shared = UserDirectory()

    struct Entry {
        var nickname: String
        var gender: ProfileGender
        var avatar: UIImage?
        var isDeleted: Bool
    }

    @Published private(set) var entries: [String: Entry] = [:]

    private init() {}

    func reload(from context: ModelContext) {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        var result: [String: Entry] = [:]
        for p in profiles {
            result[p.id] = Entry(
                nickname: p.nickname,
                gender: ProfileGender.fromCloud(p.genderCode) ?? .private_,
                avatar: p.avatarData.flatMap(UIImage.init(data:)),
                isDeleted: p.isDeleted
            )
        }
        entries = result
    }

    func clear() {
        entries = [:]
    }

    func isMe(_ userID: String) -> Bool {
        !userID.isEmpty && userID == AccountSession.currentUserID
    }

    func name(for userID: String) -> String {
        if isMe(userID) { return AppSettings.shared.displayName }
        let n = entries[userID]?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? L("一位路过的人") : n
    }

    func gender(for userID: String) -> ProfileGender {
        if isMe(userID) { return AppSettings.shared.gender }
        return entries[userID]?.gender ?? .private_
    }

    func avatar(for userID: String) -> UIImage? {
        if isMe(userID) { return AppSettings.shared.avatarImage }
        return entries[userID]?.avatar
    }

    func isDeleted(_ userID: String) -> Bool {
        if isMe(userID) { return false }
        return entries[userID]?.isDeleted == true
    }
}
