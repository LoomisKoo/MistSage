import CloudKit

enum CloudRef {
    static func user(_ userID: String) -> CKRecord.Reference {
        CKRecord.Reference(recordID: CKRecord.ID(recordName: userID), action: .none)
    }

    static func to(_ recordName: String) -> CKRecord.Reference {
        CKRecord.Reference(recordID: CKRecord.ID(recordName: recordName), action: .none)
    }
}

extension CKRecord {
    /// 要上传的记录统一从这里建：都带上分区，以后拆成国内 / 海外两个容器时按 region 迁移。
    /// Review 的 fill 会再写一次它发布时固定的 region
    static func outgoing(_ type: String, _ recordID: CKRecord.ID) -> CKRecord {
        let record = CKRecord(recordType: type, recordID: recordID)
        record["region"] = AppRegion.current.rawValue
        return record
    }

    func string(_ key: String) -> String { self[key] as? String ?? "" }
    func double(_ key: String) -> Double { self[key] as? Double ?? 0 }
    func int(_ key: String) -> Int { self[key] as? Int ?? 0 }
    func bool(_ key: String) -> Bool { (self[key] as? Int ?? 0) != 0 }
    func date(_ key: String) -> Date? { self[key] as? Date }
    func refName(_ key: String) -> String {
        (self[key] as? CKRecord.Reference)?.recordID.recordName ?? ""
    }
}

extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0 ..< Swift.min($0 + size, count)]) }
    }
}

// MARK: - Decision

extension DecisionRecord {
    func fill(_ r: CKRecord) {
        r["owner"] = CloudRef.user(ownerID)
        r["title"] = title
        r["kind"] = kind.cloudCode
        r["topic"] = topic.cloudCode
        r["money"] = money
        r["minutes"] = minutes
        r["note"] = note
        r["createdAt"] = createdAt
    }

    func apply(_ r: CKRecord) {
        ownerID = r.refName("owner")
        title = r.string("title")
        kind = DecisionKind.fromCloud(r["kind"] as? String) ?? .did
        topic = DecisionTopic.fromCloud(r["topic"] as? String) ?? .other
        money = r.double("money")
        minutes = r.int("minutes")
        note = r.string("note")
        createdAt = r.date("createdAt") ?? r.creationDate ?? .now
        needsUpload = false
    }

    static func make(from r: CKRecord) -> DecisionRecord? {
        guard let id = UUID(uuidString: r.recordID.recordName) else { return nil }
        let item = DecisionRecord(title: "", kind: .did)
        item.id = id
        item.apply(r)
        return item
    }
}

// MARK: - Review

extension ReviewRequest {
    func fill(_ r: CKRecord) {
        r["author"] = CloudRef.user(authorID)
        r["title"] = title
        r["topic"] = topic.cloudCode
        r["money"] = money
        r["minutes"] = minutes
        r["reason"] = reason
        r["alternative"] = alternative
        r["constraints"] = constraints
        r["status"] = (ReviewStatus(rawValue: statusRaw) ?? .pending).cloudCode
        r["coolUntil"] = coolUntil
        r["decidedAt"] = decidedAt
        r["isPublic"] = isPublicOnPlaza ? 1 : 0
        r["region"] = region
        r["createdAt"] = createdAt
    }

    func apply(_ r: CKRecord) {
        authorID = r.refName("author")
        title = r.string("title")
        topic = DecisionTopic.fromCloud(r["topic"] as? String) ?? .other
        money = r.double("money")
        minutes = r.int("minutes")
        reason = r.string("reason")
        alternative = r.string("alternative")
        constraints = r.string("constraints")
        statusRaw = (ReviewStatus.fromCloud(r["status"] as? String) ?? .pending).rawValue
        coolUntil = r.date("coolUntil")
        decidedAt = r.date("decidedAt")
        isPublicOnPlaza = r.bool("isPublic")
        region = AppRegion(rawValue: r.string("region"))?.rawValue ?? AppRegion.global.rawValue
        createdAt = r.date("createdAt") ?? r.creationDate ?? .now
        needsUpload = false
    }

    static func make(from r: CKRecord) -> ReviewRequest? {
        guard let id = UUID(uuidString: r.recordID.recordName) else { return nil }
        let item = ReviewRequest(title: "")
        item.id = id
        item.apply(r)
        return item
    }
}

// MARK: - Vote

extension ReviewVote {
    func fill(_ r: CKRecord) {
        r["review"] = CloudRef.to(reviewId.uuidString)
        r["voter"] = CloudRef.user(voterID)
        r["suggestion"] = suggestion.cloudCode
        r["comment"] = comment
        r["createdAt"] = createdAt
    }

    func apply(_ r: CKRecord) {
        if let rid = UUID(uuidString: r.refName("review")) { reviewId = rid }
        voterID = r.refName("voter")
        suggestion = ReviewSuggestion.fromCloud(r["suggestion"] as? String) ?? .wait
        comment = r.string("comment")
        createdAt = r.date("createdAt") ?? r.creationDate ?? .now
        needsUpload = false
    }

    static func make(from r: CKRecord) -> ReviewVote? {
        guard let rid = UUID(uuidString: r.refName("review")) else { return nil }
        let item = ReviewVote(reviewId: rid, suggestion: .wait)
        item.apply(r)
        return item
    }
}

// MARK: - Asset

extension AssetItem {
    /// 照片本身在 Image 表，按 parent 关联；这里只存封面引用，方便列表少查一次
    func fill(_ r: CKRecord) {
        r["owner"] = CloudRef.user(ownerID)
        r["name"] = name
        r["summary"] = summary
        r["price"] = price
        r["estimatedUses"] = estimatedUses
        r["useCount"] = useCount
        r["kind"] = kind.cloudCode
        r["stockStatus"] = status.cloudCode
        r["iconName"] = iconName
        let cover = photoImageIDs.first ?? ""
        r["cover"] = cover.isEmpty ? nil : CloudRef.to(cover)
        r["isPublic"] = isPublic ? 1 : 0
        r["purchasedAt"] = purchasedAt
        r["lastUsedAt"] = lastUsedAt
        r["createdAt"] = createdAt
    }

    func apply(_ r: CKRecord) {
        ownerID = r.refName("owner")
        name = r.string("name")
        summary = r.string("summary")
        price = r.double("price")
        estimatedUses = r.int("estimatedUses")
        useCount = r.int("useCount")
        kind = AssetKind.fromCloud(r["kind"] as? String) ?? .durable
        status = AssetStockStatus.fromCloud(r["stockStatus"] as? String) ?? .plenty
        iconName = r.string("iconName")
        isPublic = r.bool("isPublic")
        purchasedAt = r.date("purchasedAt") ?? .now
        lastUsedAt = r.date("lastUsedAt")
        createdAt = r.date("createdAt") ?? r.creationDate ?? .now
        needsUpload = false
    }

    static func make(from r: CKRecord) -> AssetItem? {
        guard let id = UUID(uuidString: r.recordID.recordName) else { return nil }
        let item = AssetItem(name: "")
        item.id = id
        item.apply(r)
        return item
    }
}

// MARK: - Block

extension BlockEntry {
    func fill(_ r: CKRecord) {
        r["blocker"] = CloudRef.user(blockerID)
        r["blocked"] = CloudRef.user(blockedID)
        r["createdAt"] = createdAt
    }

    func apply(_ r: CKRecord) {
        blockerID = r.refName("blocker")
        blockedID = r.refName("blocked")
        createdAt = r.date("createdAt") ?? r.creationDate ?? .now
        needsUpload = false
    }

    static func make(from r: CKRecord) -> BlockEntry? {
        let blocked = r.refName("blocked")
        guard !blocked.isEmpty else { return nil }
        let item = BlockEntry(blockedID: blocked)
        item.apply(r)
        return item
    }
}

// MARK: - User（本人资料 ↔ AppSettings）

extension AppSettings {
    func fill(_ r: CKRecord) {
        r["nickname"] = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        r["gender"] = gender.cloudCode
        r["hourlyRate"] = hourlyRate
        r["timeCostAssist"] = timeCostAssist.cloudCode
        r["monthlyIncome"] = monthlyIncome
        r["dailyIncome"] = dailyIncome
        r["workDaysPerMonth"] = workDaysPerMonth
        r["hoursPerDay"] = hoursPerDay
        r["showDailyCost"] = showDailyCost ? 1 : 0
    }

    func applyRemote(_ r: CKRecord) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        nickname = r.string("nickname")
        genderRaw = (ProfileGender.fromCloud(r["gender"] as? String) ?? .private_).rawValue
        timeCostAssistRaw = (TimeCostAssist.fromCloud(r["timeCostAssist"] as? String) ?? .manual).rawValue
        monthlyIncome = r.double("monthlyIncome")
        dailyIncome = r.double("dailyIncome")
        let days = r.int("workDaysPerMonth")
        workDaysPerMonth = days > 0 ? days : 22
        let hours = r.double("hoursPerDay")
        hoursPerDay = hours > 0 ? hours : 8
        showDailyCost = r["showDailyCost"] == nil ? true : r.bool("showDailyCost")
        // 放最后：前面的收入字段会触发重算时薪
        hourlyRate = r.double("hourlyRate")
    }
}
