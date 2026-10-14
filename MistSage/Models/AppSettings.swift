import Foundation
import SwiftUI

enum TimeCostAssist: String, CaseIterable, Identifiable {
    case manual = "手动填写"
    case monthly = "按月收入估算"
    case daily = "按日收入估算"

    var id: String { rawValue }
}

enum ProfileGender: String, CaseIterable, Identifiable {
    case private_ = "不公开"
    case male = "男"
    case female = "女"

    var id: String { rawValue }

    /// 主页展示用；不公开则返回 nil
    var publicLabel: String? {
        switch self {
        case .private_: return nil
        case .male, .female: return localizedName
        }
    }
}

/// 仅本机生效，不同步到云端
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "明亮"
    case dark = "黑暗"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 本人资料与设置；本地缓存一份，云端以 User 表为准
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    /// 用云端数据覆盖本地时为 true，此时改动不再标记为待上传
    var isApplyingRemote = false

    @Published var hourlyRate: Double {
        didSet { defaults.set(hourlyRate, forKey: "hourlyRate"); markProfileDirty() }
    }

    @Published var showDailyCost: Bool {
        didSet { defaults.set(showDailyCost, forKey: "showDailyCost"); markProfileDirty() }
    }

    @Published var nickname: String {
        didSet { defaults.set(nickname, forKey: "nickname"); markProfileDirty() }
    }

    @Published var genderRaw: String {
        didSet { defaults.set(genderRaw, forKey: "profileGender"); markProfileDirty() }
    }

    var gender: ProfileGender {
        get { ProfileGender(rawValue: genderRaw) ?? .private_ }
        set { genderRaw = newValue.rawValue }
    }

    @Published var timeCostAssistRaw: String {
        didSet {
            defaults.set(timeCostAssistRaw, forKey: "timeCostAssist")
            recalculateHourlyIfNeeded()
            markProfileDirty()
        }
    }

    @Published var monthlyIncome: Double {
        didSet {
            defaults.set(monthlyIncome, forKey: "monthlyIncome")
            recalculateHourlyIfNeeded()
            markProfileDirty()
        }
    }

    @Published var dailyIncome: Double {
        didSet {
            defaults.set(dailyIncome, forKey: "dailyIncome")
            recalculateHourlyIfNeeded()
            markProfileDirty()
        }
    }

    /// 每月大约工作天数（按月估算用）
    @Published var workDaysPerMonth: Int {
        didSet {
            defaults.set(workDaysPerMonth, forKey: "workDaysPerMonth")
            recalculateHourlyIfNeeded()
            markProfileDirty()
        }
    }

    /// 每天大约有效工作小时
    @Published var hoursPerDay: Double {
        didSet {
            defaults.set(hoursPerDay, forKey: "hoursPerDay")
            recalculateHourlyIfNeeded()
            markProfileDirty()
        }
    }

    @Published var avatarImage: UIImage?

    /// 外观：跟随系统 / 明亮 / 黑暗（只存本机）
    @Published var appearanceRaw: String {
        didSet { defaults.set(appearanceRaw, forKey: "appearanceMode") }
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var preferredColorScheme: ColorScheme? { appearance.colorScheme }

    /// 语言：跟随系统 / English / 简体中文（只存本机）
    @Published var languageRaw: String {
        didSet {
            defaults.set(languageRaw, forKey: "appLanguage")
            LanguageOverride.apply(language)
            Task { @MainActor in CloudSync.shared.languageDidChange() }
        }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .system }
        set { languageRaw = newValue.rawValue }
    }

    var profileNeedsUpload: Bool {
        get { defaults.bool(forKey: "profileNeedsUpload") }
        set { defaults.set(newValue, forKey: "profileNeedsUpload") }
    }

    var avatarNeedsUpload: Bool {
        get { defaults.bool(forKey: "avatarNeedsUpload") }
        set { defaults.set(newValue, forKey: "avatarNeedsUpload") }
    }

    /// 本地头像对应的云端 Image recordName
    var avatarImageID: String {
        get { defaults.string(forKey: "avatarImageID") ?? "" }
        set { defaults.set(newValue, forKey: "avatarImageID") }
    }

    var timeCostAssist: TimeCostAssist {
        get { TimeCostAssist(rawValue: timeCostAssistRaw) ?? .manual }
        set { timeCostAssistRaw = newValue.rawValue }
    }

    var displayName: String {
        let n = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? L("未设置昵称") : n
    }

    var hasNickname: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var avatarInitial: String {
        let n = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "?" : String(n.prefix(1))
    }

    private var avatarURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatar.jpg")
    }

    private init() {
        hourlyRate = defaults.double(forKey: "hourlyRate")
        showDailyCost = defaults.object(forKey: "showDailyCost") as? Bool ?? true
        nickname = defaults.string(forKey: "nickname") ?? ""
        genderRaw = defaults.string(forKey: "profileGender") ?? ProfileGender.private_.rawValue
        timeCostAssistRaw = defaults.string(forKey: "timeCostAssist") ?? TimeCostAssist.manual.rawValue
        monthlyIncome = defaults.double(forKey: "monthlyIncome")
        dailyIncome = defaults.double(forKey: "dailyIncome")
        let days = defaults.integer(forKey: "workDaysPerMonth")
        workDaysPerMonth = days > 0 ? days : 22
        let hours = defaults.double(forKey: "hoursPerDay")
        hoursPerDay = hours > 0 ? hours : 8
        appearanceRaw = defaults.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        let savedLanguage = defaults.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        languageRaw = savedLanguage
        LanguageOverride.apply(AppLanguage(rawValue: savedLanguage) ?? .system)
        if let data = try? Data(contentsOf: avatarURL) {
            avatarImage = UIImage(data: data)
        }
    }

    private func markProfileDirty() {
        guard !isApplyingRemote else { return }
        profileNeedsUpload = true
        CloudSync.requestPush()
    }

    func recalculateHourlyIfNeeded() {
        switch timeCostAssist {
        case .manual:
            break
        case .monthly:
            let hours = Double(max(workDaysPerMonth, 1)) * max(hoursPerDay, 0.5)
            guard monthlyIncome > 0, hours > 0 else { return }
            hourlyRate = (monthlyIncome / hours * 100).rounded() / 100
        case .daily:
            guard dailyIncome > 0, hoursPerDay > 0 else { return }
            hourlyRate = (dailyIncome / max(hoursPerDay, 0.5) * 100).rounded() / 100
        }
    }

    func saveAvatar(_ image: UIImage) {
        let normalized = image.normalizedUpOrientation()
        avatarImage = normalized
        guard let data = normalized.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: avatarURL, options: .atomic)
        avatarNeedsUpload = true
        CloudSync.requestPush()
    }

    func clearAvatar() {
        avatarImage = nil
        try? FileManager.default.removeItem(at: avatarURL)
        avatarNeedsUpload = true
        CloudSync.requestPush()
    }

    /// 云端头像写到本地，不触发上传
    func applyRemoteAvatar(_ data: Data?, imageID: String) {
        if let data, let image = UIImage(data: data) {
            avatarImage = image
            try? data.write(to: avatarURL, options: .atomic)
        } else {
            avatarImage = nil
            try? FileManager.default.removeItem(at: avatarURL)
        }
        avatarImageID = imageID
    }

    /// iCloud 账号切换或退出时清空本人资料
    func resetForAccountChange() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        nickname = ""
        genderRaw = ProfileGender.private_.rawValue
        timeCostAssistRaw = TimeCostAssist.manual.rawValue
        monthlyIncome = 0
        dailyIncome = 0
        workDaysPerMonth = 22
        hoursPerDay = 8
        showDailyCost = true
        hourlyRate = 0
        applyRemoteAvatar(nil, imageID: "")
        profileNeedsUpload = false
        avatarNeedsUpload = false
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
