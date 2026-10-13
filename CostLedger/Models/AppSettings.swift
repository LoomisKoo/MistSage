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
        case .male, .female: return rawValue
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var hourlyRate: Double {
        didSet { defaults.set(hourlyRate, forKey: "hourlyRate") }
    }

    @Published var showDailyCost: Bool {
        didSet { defaults.set(showDailyCost, forKey: "showDailyCost") }
    }

    @Published var nickname: String {
        didSet { defaults.set(nickname, forKey: "nickname") }
    }

    @Published var genderRaw: String {
        didSet { defaults.set(genderRaw, forKey: "profileGender") }
    }

    var gender: ProfileGender {
        get { ProfileGender(rawValue: genderRaw) ?? .private_ }
        set { genderRaw = newValue.rawValue }
    }

    @Published var timeCostAssistRaw: String {
        didSet {
            defaults.set(timeCostAssistRaw, forKey: "timeCostAssist")
            recalculateHourlyIfNeeded()
        }
    }

    @Published var monthlyIncome: Double {
        didSet {
            defaults.set(monthlyIncome, forKey: "monthlyIncome")
            recalculateHourlyIfNeeded()
        }
    }

    @Published var dailyIncome: Double {
        didSet {
            defaults.set(dailyIncome, forKey: "dailyIncome")
            recalculateHourlyIfNeeded()
        }
    }

    /// 每月大约工作天数（按月估算用）
    @Published var workDaysPerMonth: Int {
        didSet {
            defaults.set(workDaysPerMonth, forKey: "workDaysPerMonth")
            recalculateHourlyIfNeeded()
        }
    }

    /// 每天大约有效工作小时
    @Published var hoursPerDay: Double {
        didSet {
            defaults.set(hoursPerDay, forKey: "hoursPerDay")
            recalculateHourlyIfNeeded()
        }
    }

    @Published var avatarImage: UIImage?

    var timeCostAssist: TimeCostAssist {
        get { TimeCostAssist(rawValue: timeCostAssistRaw) ?? .manual }
        set { timeCostAssistRaw = newValue.rawValue }
    }

    var displayName: String {
        let n = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "未设置昵称" : n
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
        if let data = try? Data(contentsOf: avatarURL) {
            avatarImage = UIImage(data: data)
        }
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
    }

    func clearAvatar() {
        avatarImage = nil
        try? FileManager.default.removeItem(at: avatarURL)
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
