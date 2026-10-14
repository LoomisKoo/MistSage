import CloudKit
import SwiftData
import SwiftUI

/// 数据服务层：界面只读写 SwiftData，本类负责与 CloudKit 公开库双向同步
@MainActor
final class CloudSync: ObservableObject {
    static let shared = CloudSync()

    enum AccountState: Equatable {
        case checking
        case available
        case noAccount
        case unavailable(String)
    }

    @Published private(set) var state: AccountState = .checking
    @Published private(set) var isSyncing = false
    @Published private(set) var isDeletingAccount = false
    @Published private(set) var lastError: String?

    var canWrite: Bool {
        state == .available && AccountSession.isSignedIn && !AccountSession.isPendingDeletion
    }

    private let container = CKContainer(identifier: CloudConfig.containerID)
    private var db: CKDatabase { container.publicCloudDatabase }
    private var context: ModelContext?
    private var pushTask: Task<Void, Never>?
    private var needsAnotherPass = false
    private var observers: [NSObjectProtocol] = []

    private init() {}

    // MARK: - 启动

    func start(context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        UserDirectory.shared.reload(from: context)

        observers.append(NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in await CloudSync.shared.bootstrap() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in CloudSync.shared.schedulePush() }
        })

        Task { await bootstrap() }
    }

    /// 已生成的错误提示还是旧语言：清掉，云端不可用时重新检查一次，让提示按新语言重新生成
    func languageDidChange() {
        lastError = nil
        if case .unavailable = state {
            Task { await bootstrap() }
        }
    }

    /// 供非主线程上下文（如模型方法）调用
    nonisolated static func requestPush() {
        Task { @MainActor in CloudSync.shared.schedulePush() }
    }

    func bootstrap() async {
        guard context != nil else { return }
        await AppRegion.refresh()

        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            state = AccountSession.isSignedIn ? .available : .unavailable(L("无法确认 iCloud 状态"))
            return
        }

        switch status {
        case .available:
            break
        case .noAccount, .restricted:
            if AccountSession.isSignedIn || !AccountSession.icloudRecordName.isEmpty {
                resetLocalAccount()
            }
            state = .noAccount
            await syncNow()
            return
        default:
            state = AccountSession.isSignedIn ? .available : .unavailable(L("iCloud 暂时不可用，稍后会自动重试"))
            await syncNow()
            return
        }

        do {
            let icloudID = try await container.userRecordID().recordName

            // 上次注销没删完：先继续清云端，清完再当新用户启动
            if AccountSession.isPendingDeletion {
                if AccountSession.deletionICloudID.isEmpty {
                    AccountSession.deletionICloudID = icloudID
                }
                state = .noAccount
                await purgeCloudData()
                if AccountSession.isPendingDeletion {
                    lastError = L("账号清理尚未完成，联网后会自动继续")
                    return
                }
            }

            if AccountSession.icloudRecordName != icloudID {
                if !AccountSession.icloudRecordName.isEmpty {
                    resetLocalAccount()
                }
                AccountSession.icloudRecordName = icloudID
            }

            // 重装后：Identity 还在且 User.state=deleted → 接着清
            if let existing = try await fetchDeletedUserIfNeeded(icloudID: icloudID) {
                AccountSession.beginDeletion(
                    userID: existing.recordID.recordName,
                    icloudID: icloudID
                )
                resetLocalAccount()
                state = .noAccount
                await purgeCloudData()
                if AccountSession.isPendingDeletion {
                    lastError = L("账号清理尚未完成，联网后会自动继续")
                    return
                }
            }

            let user = try await resolveUser(icloudID: icloudID)
            AccountSession.currentUserID = user.recordID.recordName
            state = .available
            try await reconcileProfile(with: user)
            await syncNow()
            await NoticeCenter.shared.refreshRegistration()
        } catch {
            // 离线时沿用上次的账号，联网后再同步
            state = AccountSession.isSignedIn ? .available : .unavailable(Self.describe(error))
            lastError = Self.describe(error)
        }
    }

    /// Identity → User 且 state=deleted 时返回该 User，否则 nil
    private func fetchDeletedUserIfNeeded(icloudID: String) async throws -> CKRecord? {
        guard !AccountSession.isPendingDeletion else { return nil }
        let identityID = CKRecord.ID(recordName: "icloud_\(icloudID)")
        guard let identity = try await fetchIfExists(identityID),
              let ref = identity["user"] as? CKRecord.Reference,
              let user = try await fetchIfExists(ref.recordID),
              user.string("state") == "deleted"
        else { return nil }
        return user
    }

    /// iCloud 身份 → Identity → User；没有就新建
    private func resolveUser(icloudID: String, allowRetry: Bool = true) async throws -> CKRecord {
        let identityID = CKRecord.ID(recordName: "icloud_\(icloudID)")
        let identity = try await fetchIfExists(identityID)

        if let identity,
           let ref = identity["user"] as? CKRecord.Reference,
           let user = try await fetchIfExists(ref.recordID) {
            return user
        }

        let settings = AppSettings.shared
        let user = CKRecord.outgoing(CloudType.user, CKRecord.ID(recordName: UUID().uuidString))
        settings.fill(user)
        user["state"] = "active"
        let savedUser = try await db.save(user)

        let newIdentity = identity ?? CKRecord.outgoing(CloudType.identity, identityID)
        newIdentity["user"] = CKRecord.Reference(recordID: savedUser.recordID, action: .none)
        do {
            _ = try await db.save(newIdentity)
        } catch let error as CKError where error.code == .serverRecordChanged && allowRetry {
            // 另一台设备同时首次启动并抢先建好了账号
            _ = try? await db.deleteRecord(withID: savedUser.recordID)
            return try await resolveUser(icloudID: icloudID, allowRetry: false)
        }

        if settings.avatarImage != nil {
            settings.avatarNeedsUpload = true
        }
        return savedUser
    }

    /// 本地有未上传的资料改动就上传，否则用云端覆盖本地
    private func reconcileProfile(with user: CKRecord) async throws {
        let settings = AppSettings.shared
        if settings.profileNeedsUpload || settings.avatarNeedsUpload {
            try await pushProfile()
            return
        }
        settings.applyRemote(user)

        let remoteAvatarID = user.refName("avatar")
        guard remoteAvatarID != settings.avatarImageID else { return }
        if remoteAvatarID.isEmpty {
            settings.applyRemoteAvatar(nil, imageID: "")
        } else if let image = try await fetchIfExists(CKRecord.ID(recordName: remoteAvatarID), keys: ["file"]) {
            settings.applyRemoteAvatar(ImageCodec.data(of: image["file"] as? CKAsset), imageID: remoteAvatarID)
        }
    }

    // MARK: - 同步入口

    func schedulePush() {
        guard canWrite else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.pushOnly()
        }
    }

    /// 回到前台：账号还没识别成功就重新识别，否则正常同步
    func refreshOnForeground() async {
        switch state {
        case .available:
            await syncNow()
        default:
            await bootstrap()
        }
    }

    /// 先上传本地改动，再拉取云端
    func syncNow() async {
        guard context != nil else { return }
        if isSyncing {
            needsAnotherPass = true
            return
        }
        isSyncing = true
        do {
            if canWrite { try await push() }
            try await pull()
            lastError = nil
        } catch {
            lastError = Self.describe(error)
        }
        isSyncing = false
        finishPass()
    }

    private func pushOnly() async {
        guard canWrite, hasLocalChanges() else { return }
        if isSyncing {
            needsAnotherPass = true
            return
        }
        isSyncing = true
        do {
            try await push()
            lastError = nil
        } catch {
            lastError = Self.describe(error)
        }
        isSyncing = false
        finishPass()
    }

    private func finishPass() {
        if needsAnotherPass {
            needsAnotherPass = false
            schedulePush()
        }
    }

    private func hasLocalChanges() -> Bool {
        guard let context else { return false }
        let settings = AppSettings.shared
        if settings.profileNeedsUpload || settings.avatarNeedsUpload { return true }
        if ((try? context.fetchCount(FetchDescriptor<PendingDeletion>())) ?? 0) > 0 { return true }
        if ((try? context.fetchCount(FetchDescriptor<OutgoingNotice>())) ?? 0) > 0 { return true }
        return hasDirty(DecisionRecord.self)
            || hasDirty(ReviewRequest.self)
            || hasDirty(ReviewVote.self)
            || hasDirty(AssetItem.self)
            || hasDirty(BlockEntry.self)
            || ((try? context.fetch(FetchDescriptor<AssetItem>())) ?? []).contains(where: \.photosNeedUpload)
    }

    private func hasDirty<T: CloudSyncable>(_ type: T.Type) -> Bool {
        ((try? context?.fetch(FetchDescriptor<T>())) ?? []).contains(where: \.needsUpload)
    }

    // MARK: - 上传

    private func push() async throws {
        guard let context else { return }
        try await pushProfile()
        try await pushDeletions()
        try await upload(DecisionRecord.self)
        try await upload(ReviewRequest.self)
        try await upload(ReviewVote.self)
        try await upload(BlockEntry.self)
        try await upload(AssetItem.self)
        try await pushAssetPhotos()
        try await upload(AssetItem.self)
        try await pushNotices()
        try context.save()
    }

    private func pushProfile() async throws {
        let settings = AppSettings.shared
        guard canWrite, settings.profileNeedsUpload || settings.avatarNeedsUpload else { return }

        let userID = CKRecord.ID(recordName: AccountSession.currentUserID)
        let record = CKRecord.outgoing(CloudType.user, userID)
        settings.fill(record)

        let uploadAvatar = settings.avatarNeedsUpload
        let oldAvatarID = settings.avatarImageID
        var newAvatarID = oldAvatarID
        if uploadAvatar {
            if let image = settings.avatarImage {
                let imageRecord = try makeImageRecord(
                    image,
                    kind: "avatar",
                    parent: CKRecord.Reference(recordID: userID, action: .none),
                    maxSide: ImageCodec.avatarMaxSide,
                    thumbSide: ImageCodec.avatarThumbSide
                )
                _ = try await db.save(imageRecord)
                newAvatarID = imageRecord.recordID.recordName
                record["avatar"] = CloudRef.to(newAvatarID)
            } else {
                newAvatarID = ""
                record["avatar"] = nil
            }
        }

        try await saveChanged([record])

        settings.profileNeedsUpload = false
        if uploadAvatar {
            settings.avatarImageID = newAvatarID
            settings.avatarNeedsUpload = false
            if !oldAvatarID.isEmpty, oldAvatarID != newAvatarID {
                _ = try? await db.deleteRecord(withID: CKRecord.ID(recordName: oldAvatarID))
            }
        }
    }

    private func pushDeletions() async throws {
        guard let context else { return }
        let pending = try context.fetch(FetchDescriptor<PendingDeletion>())
        guard !pending.isEmpty else { return }

        for chunk in pending.chunked(200) {
            let ids = chunk.map { CKRecord.ID(recordName: $0.recordName) }
            let (_, results) = try await db.modifyRecords(
                saving: [],
                deleting: ids,
                savePolicy: .changedKeys,
                atomically: false
            )
            for item in chunk {
                switch results[CKRecord.ID(recordName: item.recordName)] {
                case .success?:
                    context.delete(item)
                case .failure(let error)?:
                    let code = (error as? CKError)?.code
                    if code == .unknownItem || code == .permissionFailure {
                        context.delete(item)
                    }
                case nil:
                    break
                }
            }
        }
        try context.save()
    }

    private func upload<T: CloudSyncable>(_ type: T.Type) async throws {
        guard let context else { return }
        let dirty = try context.fetch(FetchDescriptor<T>()).filter(\.needsUpload)
        guard !dirty.isEmpty else { return }

        for chunk in dirty.chunked(200) {
            var byID: [CKRecord.ID: T] = [:]
            let records = chunk.map { item -> CKRecord in
                let record = CKRecord.outgoing(T.recordType, CKRecord.ID(recordName: item.recordName))
                item.fill(record)
                byID[record.recordID] = item
                return record
            }
            let (results, _) = try await db.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )
            for (id, result) in results {
                guard let item = byID[id] else { continue }
                switch result {
                case .success:
                    item.needsUpload = false
                case .failure(let error):
                    // 无权限或数据非法的记录重试也不会成功，避免死循环
                    let code = (error as? CKError)?.code
                    if code == .permissionFailure || code == .invalidArguments || code == .referenceViolation {
                        item.needsUpload = false
                    }
                }
            }
        }
        try context.save()
    }

    /// 新照片逐张上传；已上传的只更新排序。被移除的照片已登记在 PendingDeletion
    private func pushAssetPhotos() async throws {
        guard let context else { return }
        let assets = try context.fetch(FetchDescriptor<AssetItem>()).filter(\.photosNeedUpload)
        for asset in assets {
            var ids = asset.photoImageIDs
            if ids.count < asset.photoFileNames.count {
                ids += Array(repeating: "", count: asset.photoFileNames.count - ids.count)
            }

            var reorder: [CKRecord] = []
            for (index, fileName) in asset.photoFileNames.enumerated() {
                if ids[index].isEmpty {
                    guard let image = AssetPhotoStore.load(fileName: fileName) else { continue }
                    let record = try makeImageRecord(
                        image,
                        kind: "asset",
                        parent: CloudRef.to(asset.recordName),
                        maxSide: ImageCodec.assetMaxSide,
                        thumbSide: ImageCodec.assetThumbSide,
                        sortIndex: index
                    )
                    _ = try await db.save(record)
                    ids[index] = record.recordID.recordName
                } else {
                    let record = CKRecord.outgoing(CloudType.image, CKRecord.ID(recordName: ids[index]))
                    record["sortIndex"] = index
                    reorder.append(record)
                }
            }
            if !reorder.isEmpty {
                try await saveChanged(reorder)
            }

            asset.photoImageIDs = Array(ids.prefix(asset.photoFileNames.count))
            asset.photosNeedUpload = false
            asset.needsUpload = true
        }
        try context.save()
    }

    private func pushNotices() async throws {
        guard let context else { return }
        let notices = try context.fetch(FetchDescriptor<OutgoingNotice>())
        guard !notices.isEmpty else { return }

        let me = AccountSession.currentUserID
        for chunk in notices.chunked(200) {
            var byID: [CKRecord.ID: OutgoingNotice] = [:]
            let records = chunk.map { notice -> CKRecord in
                let record = CKRecord.outgoing(CloudType.notice, CKRecord.ID(recordName: UUID().uuidString))
                record["recipient"] = CloudRef.user(notice.recipientID)
                record["actor"] = CloudRef.user(me)
                record["kind"] = notice.kindRaw
                record["review"] = CloudRef.to(notice.reviewID)
                record["reviewTitle"] = notice.reviewTitle
                record["createdAt"] = notice.createdAt
                byID[record.recordID] = notice
                return record
            }
            let (results, _) = try await db.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )
            for (id, result) in results {
                guard let notice = byID[id] else { continue }
                switch result {
                case .success:
                    context.delete(notice)
                case .failure(let error):
                    // 通知只是锦上添花，非网络问题直接丢弃
                    let code = (error as? CKError)?.code
                    if code != .networkUnavailable && code != .networkFailure && code != .serviceUnavailable {
                        context.delete(notice)
                    }
                }
            }
        }
        try context.save()
    }

    private func makeImageRecord(
        _ image: UIImage,
        kind: String,
        parent: CKRecord.Reference,
        maxSide: CGFloat,
        thumbSide: CGFloat,
        sortIndex: Int = 0
    ) throws -> CKRecord {
        guard let full = ImageCodec.jpeg(image, maxSide: maxSide),
              let thumb = ImageCodec.jpeg(image, maxSide: thumbSide, quality: 0.7)
        else { throw CKError(.invalidArguments) }

        let record = CKRecord.outgoing(CloudType.image, CKRecord.ID(recordName: UUID().uuidString))
        record["owner"] = CloudRef.user(AccountSession.currentUserID)
        record["kind"] = kind
        record["parent"] = parent
        record["file"] = try ImageCodec.asset(from: full.data)
        record["thumbnail"] = try ImageCodec.asset(from: thumb.data)
        record["sortIndex"] = sortIndex
        record["width"] = Int(full.size.width)
        record["height"] = Int(full.size.height)
        return record
    }

    // MARK: - 拉取

    private func pull() async throws {
        guard let context else { return }
        let signedIn = canWrite
        let me = AccountSession.currentUserID

        var reviews: [CKRecord.ID: CKRecord] = [:]
        let plaza = try await query(
            CloudType.review,
            NSPredicate(format: "isPublic == 1 AND region == %@", AppRegion.current.rawValue),
            sort: [NSSortDescriptor(key: "createdAt", ascending: false)],
            limit: 200
        )
        plaza.forEach { reviews[$0.recordID] = $0 }

        var decisions: [CKRecord] = []
        var assets: [CKRecord] = []
        var blocks: [CKRecord] = []
        var votes: [CKRecord.ID: CKRecord] = [:]

        if signedIn {
            let meRef = CloudRef.user(me)
            try await queryAll(CloudType.review, NSPredicate(format: "author == %@", meRef))
                .forEach { reviews[$0.recordID] = $0 }
            decisions = try await queryAll(CloudType.decision, NSPredicate(format: "owner == %@", meRef))
            assets = try await queryAll(CloudType.asset, NSPredicate(format: "owner == %@", meRef))
            blocks = try await queryAll(CloudType.block, NSPredicate(format: "blocker == %@", meRef))

            // 我参与过的帖子可能不在广场前 200 条里
            let myVotes = try await queryAll(CloudType.vote, NSPredicate(format: "voter == %@", meRef))
            myVotes.forEach { votes[$0.recordID] = $0 }
            let missing = Set(myVotes.compactMap { ($0["review"] as? CKRecord.Reference)?.recordID })
                .subtracting(reviews.keys)
            for record in try await fetchRecords(Array(missing)) {
                reviews[record.recordID] = record
            }
        }

        let reviewRefs = reviews.keys.map { CKRecord.Reference(recordID: $0, action: .none) }
        for chunk in reviewRefs.chunked(100) {
            try await queryAll(CloudType.vote, NSPredicate(format: "review IN %@", chunk))
                .forEach { votes[$0.recordID] = $0 }
        }

        var userIDs = Set<String>()
        reviews.values.forEach { userIDs.insert($0.refName("author")) }
        votes.values.forEach { userIDs.insert($0.refName("voter")) }
        userIDs.remove("")
        userIDs.remove(me)
        try await refreshUsers(Array(userIDs))

        let pending = Set(try context.fetch(FetchDescriptor<PendingDeletion>()).map(\.recordName))
        try merge(ReviewRequest.self, records: Array(reviews.values), pending: pending)
        try merge(ReviewVote.self, records: Array(votes.values), pending: pending)
        if signedIn {
            try merge(DecisionRecord.self, records: decisions, pending: pending)
            try merge(AssetItem.self, records: assets, pending: pending)
            try merge(BlockEntry.self, records: blocks, pending: pending)
            try await syncAssetPhotos(assets, pending: pending)
        }
        try context.save()
    }

    /// 云端覆盖本地（本地有未上传改动的除外），并删掉云端已不存在的本地记录
    private func merge<T: CloudSyncable>(_ type: T.Type, records: [CKRecord], pending: Set<String>) throws {
        guard let context else { return }
        let locals = try context.fetch(FetchDescriptor<T>())
        var byName = Dictionary(locals.map { ($0.recordName, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()

        for record in records {
            let name = record.recordID.recordName
            seen.insert(name)
            guard !pending.contains(name) else { continue }
            if let local = byName[name] {
                if !local.needsUpload { local.apply(record) }
            } else if let created = T.make(from: record) {
                context.insert(created)
                byName[name] = created
            }
        }

        for local in locals where !seen.contains(local.recordName) && !local.needsUpload {
            context.delete(local)
        }
    }

    private func refreshUsers(_ ids: [String]) async throws {
        guard let context, !ids.isEmpty else { return }
        var cached = Dictionary(
            try context.fetch(FetchDescriptor<UserProfile>()).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var avatarsToFetch: [CKRecord.ID: UserProfile] = [:]

        for chunk in ids.chunked(200) {
            let records = try await fetchRecords(
                chunk.map { CKRecord.ID(recordName: $0) },
                keys: ["nickname", "gender", "avatar", "state"]
            )
            for record in records {
                let id = record.recordID.recordName
                let profile: UserProfile
                if let existing = cached[id] {
                    profile = existing
                } else {
                    profile = UserProfile(id: id)
                    context.insert(profile)
                    cached[id] = profile
                }
                profile.nickname = record.string("nickname")
                profile.genderCode = record.string("gender")
                let remoteState = record.string("state")
                profile.stateCode = remoteState.isEmpty ? "active" : remoteState
                profile.updatedAt = .now

                let avatarID = record.refName("avatar")
                if avatarID.isEmpty {
                    profile.avatarImageID = ""
                    profile.avatarData = nil
                } else if avatarID != profile.avatarImageID {
                    avatarsToFetch[CKRecord.ID(recordName: avatarID)] = profile
                }
            }
        }

        for record in try await fetchRecords(Array(avatarsToFetch.keys), keys: ["thumbnail"]) {
            guard let profile = avatarsToFetch[record.recordID] else { continue }
            profile.avatarData = ImageCodec.data(of: record["thumbnail"] as? CKAsset)
            profile.avatarImageID = record.recordID.recordName
        }

        try context.save()
        UserDirectory.shared.reload(from: context)
    }

    /// 以云端 Image 表为准对齐本机资产照片，只下载本机没有的
    private func syncAssetPhotos(_ assetRecords: [CKRecord], pending: Set<String>) async throws {
        guard let context, !assetRecords.isEmpty else { return }
        let images = try await queryAll(
            CloudType.image,
            NSPredicate(format: "owner == %@ AND kind == %@", CloudRef.user(AccountSession.currentUserID), "asset"),
            keys: ["parent", "sortIndex"]
        )
        var remoteByAsset: [String: [(id: String, index: Int)]] = [:]
        for image in images where !pending.contains(image.recordID.recordName) {
            remoteByAsset[image.refName("parent"), default: []]
                .append((image.recordID.recordName, image.int("sortIndex")))
        }
        let coverByAsset = Dictionary(
            assetRecords.map { ($0.recordID.recordName, $0.refName("cover")) },
            uniquingKeysWith: { first, _ in first }
        )

        var plans: [(asset: AssetItem, ids: [String])] = []
        var toFetch: [CKRecord.ID: AssetItem] = [:]
        for asset in try context.fetch(FetchDescriptor<AssetItem>())
        where !asset.photosNeedUpload && !asset.needsUpload {
            let remoteIDs = (remoteByAsset[asset.recordName] ?? []).sorted { $0.index < $1.index }.map(\.id)
            guard remoteIDs != asset.photoImageIDs else { continue }
            // 查询索引有延迟：封面还没出现在结果里时，这次先不动
            let cover = coverByAsset[asset.recordName] ?? ""
            if !cover.isEmpty, !remoteIDs.contains(cover) { continue }

            plans.append((asset, remoteIDs))
            for id in remoteIDs where !asset.photoImageIDs.contains(id) {
                toFetch[CKRecord.ID(recordName: id)] = asset
            }
        }
        guard !plans.isEmpty else { return }

        var downloaded: [String: String] = [:]
        for record in try await fetchRecords(Array(toFetch.keys), keys: ["file"]) {
            guard let asset = toFetch[record.recordID],
                  let data = ImageCodec.data(of: record["file"] as? CKAsset)
            else { continue }
            let id = record.recordID.recordName
            let fileName = "\(asset.id.uuidString)_\(id).jpg"
            if AssetPhotoStore.save(data: data, fileName: fileName) {
                downloaded[id] = fileName
            }
        }

        for (asset, remoteIDs) in plans {
            let localByID = Dictionary(
                zip(asset.photoImageIDs, asset.photoFileNames).filter { !$0.0.isEmpty },
                uniquingKeysWith: { first, _ in first }
            )
            var names: [String] = []
            var ids: [String] = []
            for id in remoteIDs {
                guard let fileName = localByID[id] ?? downloaded[id] else { continue }
                names.append(fileName)
                ids.append(id)
            }
            for old in asset.photoFileNames where !names.contains(old) {
                AssetPhotoStore.delete(fileName: old)
            }
            asset.photoFileNames = names
            asset.photoImageIDs = ids
        }
    }

    /// 资产详情页的大图，按需从云端取
    func fetchAssetPhotos(assetRecordName: String) async -> [UIImage] {
        do {
            let records = try await queryAll(
                CloudType.image,
                NSPredicate(format: "parent == %@", CloudRef.to(assetRecordName)),
                keys: ["file", "sortIndex"]
            )
            return records
                .sorted { $0.int("sortIndex") < $1.int("sortIndex") }
                .compactMap { ImageCodec.data(of: $0["file"] as? CKAsset).flatMap(UIImage.init(data:)) }
        } catch {
            return []
        }
    }

    /// 别人主页的公开资产：不进本地库，只临时展示
    func fetchPublicAssets(of userID: String) async -> [AssetItem] {
        guard !userID.isEmpty else { return [] }
        do {
            let records = try await query(
                CloudType.asset,
                NSPredicate(format: "owner == %@ AND isPublic == 1", CloudRef.user(userID)),
                sort: [NSSortDescriptor(key: "createdAt", ascending: false)],
                limit: 100
            )
            let items = records.compactMap { AssetItem.make(from: $0) }
            var byCover: [CKRecord.ID: AssetItem] = [:]
            for (record, item) in zip(records, items) {
                let cover = record.refName("cover")
                if !cover.isEmpty { byCover[CKRecord.ID(recordName: cover)] = item }
            }
            for image in try await fetchRecords(Array(byCover.keys), keys: ["thumbnail"]) {
                guard let item = byCover[image.recordID],
                      let data = ImageCodec.data(of: image["thumbnail"] as? CKAsset)
                else { continue }
                let fileName = "remote_\(image.recordID.recordName).jpg"
                if AssetPhotoStore.save(data: data, fileName: fileName) {
                    item.photoFileNames = [fileName]
                    item.photoImageIDs = [image.recordID.recordName]
                }
            }
            return items
        } catch {
            return []
        }
    }

    // MARK: - 举报 / 通知订阅

    /// 举报直接写云端，由开发者在 CloudKit Dashboard 审核
    func report(_ target: ReportTarget, reason: ReportReason, detail: String) async -> Bool {
        guard canWrite else { return false }
        let record = CKRecord.outgoing(CloudType.report, CKRecord.ID(recordName: UUID().uuidString))
        record["reporter"] = CloudRef.user(AccountSession.currentUserID)
        record["targetType"] = target.typeCode
        record["target"] = target.recordName
        record["targetUser"] = target.userID.isEmpty ? nil : CloudRef.user(target.userID)
        record["reason"] = reason.cloudCode
        record["detail"] = detail
        record["createdAt"] = Date.now
        do {
            _ = try await db.save(record)
            return true
        } catch {
            lastError = Self.describe(error)
            return false
        }
    }

    /// 订阅发给我的 Notice，由 CloudKit 推送；其他账号留下的订阅一并清掉
    func ensureNoticeSubscriptions() async {
        guard canWrite else { return }
        let me = AccountSession.currentUserID
        let wanted = NoticeKind.allCases.map { "notice-\($0.rawValue)-\(me)" }
        do {
            let existing = try await db.allSubscriptions().map(\.subscriptionID)
            let stale = existing.filter { $0.hasPrefix("notice-") && !wanted.contains($0) }
            let missing = NoticeKind.allCases.filter { !existing.contains("notice-\($0.rawValue)-\(me)") }
            guard !stale.isEmpty || !missing.isEmpty else { return }

            let subscriptions = missing.map { kind -> CKSubscription in
                let sub = CKQuerySubscription(
                    recordType: CloudType.notice,
                    predicate: NSPredicate(format: "recipient == %@ AND kind == %@", CloudRef.user(me), kind.rawValue),
                    subscriptionID: "notice-\(kind.rawValue)-\(me)",
                    options: [.firesOnRecordCreation]
                )
                let info = CKSubscription.NotificationInfo()
                info.alertLocalizationKey = "NOTICE_\(kind.rawValue.uppercased())"
                info.alertLocalizationArgs = ["reviewTitle"]
                info.soundName = "default"
                info.desiredKeys = ["review"]
                sub.notificationInfo = info
                return sub
            }
            _ = try await db.modifySubscriptions(saving: subscriptions, deleting: stale)
        } catch {
            // 推送订阅失败不影响主流程，下次启动再试
        }
    }

    // MARK: - 注销账号

    /// 先标记 deleted 并清本地，再分批删云端；中断后下次启动继续
    func deleteAccount() async -> Bool {
        guard canWrite else { return false }
        let me = AccountSession.currentUserID
        let icloudID = AccountSession.icloudRecordName
        guard !me.isEmpty, !icloudID.isEmpty else { return false }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            let record = CKRecord.outgoing(CloudType.user, CKRecord.ID(recordName: me))
            record["state"] = "deleted"
            try await saveChanged([record])
        } catch {
            lastError = Self.describe(error)
            return false
        }

        AccountSession.beginDeletion(userID: me, icloudID: icloudID)
        await removeNoticeSubscriptions()
        NoticeCenter.cancelAllCoolingReminders()
        resetLocalAccount()
        state = .noAccount

        await purgeCloudData()
        if !AccountSession.isPendingDeletion {
            await bootstrap()
        } else {
            lastError = L("账号已注销，云端数据将在后台继续清理")
        }
        return true
    }

    /// 幂等：查还剩什么就删什么；User / Identity 放最后
    private func purgeCloudData() async {
        let me = AccountSession.deletionUserID
        let icloudID = AccountSession.deletionICloudID
        guard AccountSession.isPendingDeletion, !me.isEmpty else {
            AccountSession.finishDeletion()
            return
        }

        isDeletingAccount = true
        var bgTask = UIBackgroundTaskIdentifier.invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "MistSageAccountDeletion") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        defer {
            isDeletingAccount = false
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }

        let meRef = CloudRef.user(me)
        do {
            try await deleteMatching(CloudType.image, NSPredicate(format: "owner == %@", meRef))
            try await deleteMatching(CloudType.asset, NSPredicate(format: "owner == %@", meRef))
            try await deleteMatching(CloudType.decision, NSPredicate(format: "owner == %@", meRef))
            try await deleteMatching(CloudType.vote, NSPredicate(format: "voter == %@", meRef))
            try await deleteMatching(CloudType.review, NSPredicate(format: "author == %@", meRef))
            try await deleteMatching(CloudType.block, NSPredicate(format: "blocker == %@", meRef))
            // Report / 别人写给我的 Notice 不删：无个人资料，且无权限删他人创建的记录

            // User / Identity 删不掉就留下，下次再试
            if try await fetchIfExists(CKRecord.ID(recordName: me)) != nil {
                _ = try await db.deleteRecord(withID: CKRecord.ID(recordName: me))
            }
            let identityID = CKRecord.ID(recordName: "icloud_\(icloudID)")
            if try await fetchIfExists(identityID) != nil {
                _ = try await db.deleteRecord(withID: identityID)
            }

            await removeNoticeSubscriptions()
            AccountSession.finishDeletion()
            lastError = nil
        } catch {
            lastError = Self.describe(error)
        }
    }

    private func deleteMatching(_ type: String, _ predicate: NSPredicate) async throws {
        let records = try await queryAll(type, predicate)
        guard !records.isEmpty else { return }
        for chunk in records.map(\.recordID).chunked(200) {
            let (_, results) = try await db.modifyRecords(
                saving: [],
                deleting: chunk,
                savePolicy: .changedKeys,
                atomically: false
            )
            for (_, result) in results {
                if case .failure(let error) = result {
                    let code = (error as? CKError)?.code
                    if code == .unknownItem || code == .permissionFailure { continue }
                    throw error
                }
            }
        }
    }

    private func removeNoticeSubscriptions() async {
        do {
            let stale = try await db.allSubscriptions()
                .map(\.subscriptionID)
                .filter { $0.hasPrefix("notice-") }
            guard !stale.isEmpty else { return }
            _ = try await db.modifySubscriptions(saving: [], deleting: stale)
        } catch {}
    }

    // MARK: - 账号切换

    private func resetLocalAccount() {
        if let context {
            wipe(DecisionRecord.self, in: context)
            wipe(ReviewRequest.self, in: context)
            wipe(ReviewVote.self, in: context)
            wipe(AssetItem.self, in: context)
            wipe(BlockEntry.self, in: context)
            wipe(OutgoingNotice.self, in: context)
            wipe(PendingDeletion.self, in: context)
            wipe(UserProfile.self, in: context)
            try? context.save()
        }
        NoticeCenter.cancelAllCoolingReminders()
        AssetPhotoStore.deleteAll()
        AccountSession.clear()
        AppSettings.shared.resetForAccountChange()
        UserDirectory.shared.clear()
    }

    private func wipe<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        for item in (try? context.fetch(FetchDescriptor<T>())) ?? [] {
            context.delete(item)
        }
    }

    // MARK: - CloudKit 封装

    private func fetchIfExists(_ id: CKRecord.ID, keys: [CKRecord.FieldKey]? = nil) async throws -> CKRecord? {
        do {
            if let keys {
                return try await fetchRecords([id], keys: keys).first
            }
            return try await db.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func fetchRecords(_ ids: [CKRecord.ID], keys: [CKRecord.FieldKey]? = nil) async throws -> [CKRecord] {
        guard !ids.isEmpty else { return [] }
        var out: [CKRecord] = []
        for chunk in ids.chunked(200) {
            let results = try await db.records(for: chunk, desiredKeys: keys)
            out += results.values.compactMap { try? $0.get() }
        }
        return out
    }

    private func saveChanged(_ records: [CKRecord]) async throws {
        let (results, _) = try await db.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .changedKeys,
            atomically: false
        )
        for (_, result) in results {
            if case .failure(let error) = result { throw error }
        }
    }

    private func query(
        _ type: String,
        _ predicate: NSPredicate,
        sort: [NSSortDescriptor] = [],
        limit: Int
    ) async throws -> [CKRecord] {
        let q = CKQuery(recordType: type, predicate: predicate)
        q.sortDescriptors = sort
        do {
            let (results, _) = try await db.records(matching: q, resultsLimit: limit)
            return results.compactMap { try? $0.1.get() }
        } catch let error as CKError where Self.isMissingSchema(error) {
            return []
        }
    }

    /// 开发环境里表还没人写过，或查询用到的字段还没有任何记录带过（字段在第一次上传时才自动创建）
    private static func isMissingSchema(_ error: CKError) -> Bool {
        if error.code == .unknownItem { return true }
        return error.code == .invalidArguments && error.localizedDescription.contains("Unknown field")
    }

    private func queryAll(
        _ type: String,
        _ predicate: NSPredicate,
        keys: [CKRecord.FieldKey]? = nil
    ) async throws -> [CKRecord] {
        let q = CKQuery(recordType: type, predicate: predicate)
        do {
            let first = try await db.records(matching: q, desiredKeys: keys)
            var out = first.matchResults.compactMap { try? $0.1.get() }
            var cursor = first.queryCursor
            while let c = cursor {
                let page = try await db.records(continuingMatchFrom: c, desiredKeys: keys)
                out += page.matchResults.compactMap { try? $0.1.get() }
                cursor = page.queryCursor
            }
            return out
        } catch let error as CKError where Self.isMissingSchema(error) {
            return []
        }
    }

    static func describe(_ error: Error) -> String {
        guard let ck = error as? CKError else { return error.localizedDescription }
        switch ck.code {
        case .networkUnavailable, .networkFailure: return L("网络不可用，稍后自动同步")
        case .notAuthenticated: return L("请在系统设置中登录 iCloud")
        case .quotaExceeded: return L("云端空间不足")
        case .requestRateLimited, .serviceUnavailable, .zoneBusy: return L("云端繁忙，稍后自动重试")
        default: return ck.localizedDescription
        }
    }
}
