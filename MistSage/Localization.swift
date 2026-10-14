import Foundation
import SwiftUI

extension RawRepresentable where RawValue == String {
    /// 用 rawValue 作 Localizable key（中文开发语言），展示用已解析文案
    var localizedName: String {
        L(String.LocalizationValue(rawValue))
    }
}

/// String(localized:) 不走 Bundle.main 的方法查找，需显式传 App 内所选语言的 bundle
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: LanguageOverride.bundle ?? .main, locale: LanguageOverride.current.locale)
}

/// 仅本机生效，不同步到云端
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    /// 语言名用各自语言显示，只有「跟随系统」随当前语言变
    var label: String {
        switch self {
        case .system: return L("跟随系统")
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }

    var code: String? { self == .system ? nil : rawValue }

    /// 界面实际显示的是否为中文（跟随系统时看系统选中的 lproj）
    var isChinese: Bool {
        (code ?? Bundle.main.preferredLocalizations.first ?? "").hasPrefix("zh")
    }

    var locale: Locale { code.map(Locale.init(identifier:)) ?? .autoupdatingCurrent }
}

/// App 内切换语言：L() 与 Text 都经由 Bundle.main 取文案，这里把查找转到所选 lproj
enum LanguageOverride {
    fileprivate static var bundle: Bundle?
    private(set) static var current: AppLanguage = .system

    static func apply(_ language: AppLanguage) {
        if !(Bundle.main is OverridableBundle) {
            object_setClass(Bundle.main, OverridableBundle.self)
        }
        // 不写 AppleLanguages：写了会改掉 Locale.current，「跟随系统」就拿不到真实系统语言
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        current = language
        if let code = language.code,
           let path = Bundle.main.path(forResource: code, ofType: "lproj") {
            bundle = Bundle(path: path)
        } else {
            bundle = nil
        }
    }
}

extension Date {
    /// 日期文字跟随 App 内语言，而不是系统语言
    func appFormatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(LanguageOverride.current.locale))
    }

    func appRelative() -> String {
        formatted(.relative(presentation: .named).locale(LanguageOverride.current.locale))
    }
}

private final class OverridableBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = LanguageOverride.bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension String {
    /// 把中文 key 解析为当前语言文案（动态字符串 / 非 Text 字面量场景）
    var localized: String {
        L(String.LocalizationValue(self))
    }
}
