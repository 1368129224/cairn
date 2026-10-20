import Foundation
import SwiftUI
import CairnCore

// MARK: - SwiftUI Environment

/// Environment key carrying the user's active `AppLanguage` preference down
/// the SwiftUI hierarchy. Driving localization from the environment instead of
/// global mutable state keeps Swift 6 strict concurrency clean and lets
/// in-app language switches re-render every screen in place without tearing
/// down navigation state via `.id(...)`.
private struct CairnLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .system
}

public extension EnvironmentValues {
    var cairnLanguage: AppLanguage {
        get { self[CairnLanguageKey.self] }
        set { self[CairnLanguageKey.self] = newValue }
    }
}

// MARK: - Bundle-backed lookup

/// Resource-backed localization lookup for `CairnIOSCore`.
///
/// Translations live in standard Apple `.lproj/Localizable.strings` tables
/// bundled via `Package.swift` (`en.lproj` and `zh-Hans.lproj`). Resolving
/// the `.lproj` sub-bundle explicitly lets an in-app language override take
/// effect immediately without restarting the process — whereas `Text(_:bundle:)`
/// on `.strings` tables follows `Bundle.preferredLocalizations` instead of
/// SwiftUI's `.environment(\.locale, ...)`.
public enum CairnL10n {

    /// Look up a localized string for `key` in `language`. Falls back to `key`
    /// when the `.lproj` bundle or entry is absent.
    public static func string(
        _ key: String,
        language: AppLanguage,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let code = language.resolvedLanguageCode(preferredLanguages: preferredLanguages)
        guard let lproj = lprojBundle(forCode: code) else {
            return key
        }
        return lproj.localizedString(forKey: key, value: key, table: "Localizable")
    }

    /// Format a localized format string (`%@`, `%lld`, `%.1f%%`, etc.) using
    /// the resolved locale for `language`.
    public static func format(
        _ key: String,
        language: AppLanguage,
        preferredLanguages: [String] = Locale.preferredLanguages,
        _ args: CVarArg...
    ) -> String {
        let pattern = string(key, language: language, preferredLanguages: preferredLanguages)
        let locale = language.resolvedLocale(preferredLanguages: preferredLanguages)
        return String(format: pattern, locale: locale, arguments: args)
    }

    /// Resolve the `.lproj` sub-bundle inside `Bundle.module` for `code`
    /// (`"en"` or `"zh-Hans"`).
    internal static func lprojBundle(forCode code: String) -> Bundle? {
        if let path = Bundle.module.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        if let path = Bundle.module.path(forResource: code, ofType: "lproj", inDirectory: "Resources"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return nil
    }
}

// MARK: - AppLanguage convenience API

public extension AppLanguage {
    /// Whether this preference currently resolves to Simplified Chinese.
    var isChinese: Bool {
        resolvesToChinese()
    }

    /// Resolved `Locale` for date/time/number formatting.
    var locale: Locale {
        resolvedLocale()
    }

    /// Translate `key` in this language via `Bundle.module`'s `.lproj` tables.
    func t(_ key: String) -> String {
        CairnL10n.string(key, language: self)
    }

    /// Format a localized string in this language.
    func f(_ key: String, _ args: CVarArg...) -> String {
        let pattern = CairnL10n.string(key, language: self)
        return String(format: pattern, locale: locale, arguments: args)
    }
}
