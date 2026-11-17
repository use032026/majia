import Foundation

/// Localization owned by STMini, deliberately independent of any host App's
/// localization implementation. Hosts set `STLanguageCode` when their language
/// changes; unknown languages fall back to English, then Simplified Chinese.
enum STMiniLocalization {
    private final class BundleMarker: NSObject {}
    private static var dictionaries: [String: [String: String]] = [:]
    private static let lock = NSLock()

    static func text(_ key: String, fallback: String) -> String {
        let language = resolvedLanguage()
        if let value = dictionary(for: language)[key], !value.isEmpty {
            return value
        }
        if language != "en", let value = dictionary(for: "en")[key], !value.isEmpty {
            return value
        }
        if language != "zh-Hans", let value = dictionary(for: "zh-Hans")[key], !value.isEmpty {
            return value
        }
        return fallback
    }

    private static func resolvedLanguage() -> String {
        let configured = (UserDefaults.standard.string(forKey: "STLanguageCode")
            ?? Locale.preferredLanguages.first
            ?? "en")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        if configured == "zh" || configured.hasPrefix("zh-hans") || configured.hasPrefix("zh-cn") {
            return "zh-Hans"
        }
        if configured.hasPrefix("zh-hant") || configured.hasPrefix("zh-tw") || configured.hasPrefix("zh-hk") {
            return "zh-Hant"
        }
        // These existing resources are region-specific; truncating to "pt"
        // would bypass both dictionaries and incorrectly fall back to English.
        if configured == "pt-br" || configured.hasPrefix("pt-br-") { return "pt-BR" }
        if configured == "pt-pt" || configured.hasPrefix("pt-pt-") { return "pt-PT" }
        return configured.split(separator: "-").first.map(String.init) ?? "en"
    }

    private static func dictionary(for language: String) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        if let dictionary = dictionaries[language] {
            return dictionary
        }
        let fileName = "Language-\(language)"
        let bundle = resourceBundle()
        guard let url = bundle.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            dictionaries[language] = [:]
            return [:]
        }
        dictionaries[language] = object
        return object
    }

    private static func resourceBundle() -> Bundle {
        let frameworkBundle = Bundle(for: BundleMarker.self)
        if let url = frameworkBundle.url(forResource: "stmini_flutter_localizations", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return frameworkBundle
    }
}

@inline(__always)
func STMiniLocalized(_ key: String, _ fallback: String) -> String {
    return STMiniLocalization.text(key, fallback: fallback)
}
