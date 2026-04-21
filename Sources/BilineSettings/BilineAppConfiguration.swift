import Foundation

public enum BilineTranslationProviderChoice: String, CaseIterable, Sendable {
    case off
    case aliyun
}

public enum BilineDefaultsKey {
    public static let translationProvider = "BilineTranslationProvider"
    public static let alibabaRegionId = "BilineAlibabaRegionId"
    public static let alibabaEndpoint = "BilineAlibabaEndpoint"
    public static let previewEnabled = "BilinePreviewEnabled"
    public static let compactColumnCount = "BilineCompactColumnCount"
    public static let expandedRowCount = "BilineExpandedRowCount"
    public static let fuzzyPinyinEnabled = "BilineFuzzyPinyinEnabled"
    public static let characterForm = "BilineCharacterForm"
    public static let punctuationForm = "BilinePunctuationForm"
    /// Stored as a JSON blob (Data) — see `KeyBindingPolicy.encode()`.
    public static let keyBindingPolicy = "BilineKeyBindingPolicy"
    /// Panel theme mode (see `PanelTheme.Mode.rawValue`).
    public static let panelThemeMode = "BilinePanelThemeMode"
    /// Panel font scale multiplier, stored as Double.
    public static let panelFontScale = "BilinePanelFontScale"

    // Phase 2 composing helpers.
    /// When enabled, committing an opening bracket also commits the matching
    /// closing bracket. Caret stays after both because IMK does not let the
    /// IME push the cursor backwards through the host text storage.
    public static let autoPairBrackets = "BilineAutoPairBrackets"
    /// When enabled, `/` is rewritten to `、` (ideographic enumeration mark)
    /// in Chinese punctuation mode.
    public static let slashAsChineseEnumeration = "BilineSlashAsChineseEnumeration"
    /// When enabled, an ASCII letter or digit committed right after a
    /// Chinese character (and vice versa) is prefixed with a thin space.
    public static let autoSpaceBetweenChineseAndAscii = "BilineAutoSpaceBetweenChineseAndAscii"
    /// When enabled, a colon committed inside a `digit colon space digit`
    /// sequence collapses the spaces (e.g. `12: 00` -> `12:00`).
    public static let normalizeNumericColon = "BilineNormalizeNumericColon"

    // Phase 3 per-context.
    /// When enabled, all network-backed preview/translation calls are
    /// suppressed regardless of `previewEnabled`. Settings UI exposes this
    /// as 单机模式.
    public static let offlineMode = "BilineOfflineMode"
    /// Stored as `[String]` (CFArray of CFString). Bundle identifiers in
    /// this list start each new composition in the English layer instead of
    /// Chinese.
    public static let englishDefaultBundleIDs = "BilineEnglishDefaultBundleIDs"

    // Phase 4 (engine-side, behavior in follow-up milestones).
    /// Toggle for Rime's `spelling_corrector` filter. The Swift IME stores
    /// the user's preference here; activating the actual filter is a Rime
    /// schema-side change tracked as a separate milestone.
    public static let smartSpellingEnabled = "BilineSmartSpellingEnabled"
    /// Toggle for emoji candidate injection. Stored ahead of the engine
    /// integration so the Settings UI can land first; the actual candidate
    /// merge is Phase 4 engine work.
    public static let emojiCandidatesEnabled = "BilineEmojiCandidatesEnabled"
}

public enum BilineAppIdentifier {
    public static let devInputMethodBundle = "io.github.xixiphus.inputmethod.BilineIME.dev"
    public static let devInputSource = "io.github.xixiphus.inputmethod.BilineIME.dev.pinyin"
    public static let devSettingsBundle = "io.github.xixiphus.inputmethod.BilineIME.settings.dev"
    public static let releaseInputMethodBundle = "io.github.xixiphus.inputmethod.BilineIME"
    public static let releaseInputSource = "io.github.xixiphus.inputmethod.BilineIME.pinyin"
}

public enum BilineAppProcessName {
    public static let devInputMethod = "BilineIMEDev"
    public static let devSettings = "BilineSettingsDev"
    public static let releaseInputMethod = "BilineIME"
}

public enum BilineAppPath {
    public static var devInputMethodInstallURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Input Methods/BilineIMEDev.app", isDirectory: true)
    }

    public static var devSettingsInstallURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/BilineSettingsDev.app", isDirectory: true)
    }

    public static func credentialFileURL(inputMethodBundleIdentifier: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Containers/\(inputMethodBundleIdentifier)/Data/Library/Application Support/BilineIME",
                isDirectory: true
            )
            .appendingPathComponent("alibaba-credentials.json", isDirectory: false)
    }

    public static func inputMethodRuntimeCredentialFileURL() -> URL {
        let applicationSupport =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return
            applicationSupport
            .appendingPathComponent("BilineIME", isDirectory: true)
            .appendingPathComponent("alibaba-credentials.json", isDirectory: false)
    }

    public static func inputMethodRuntimeRimeUserDictionaryURL(characterForm: String = "simplified")
        -> URL
    {
        let applicationSupport =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return
            applicationSupport
            .appendingPathComponent(
                "Rime/user/\(rimeUserDictionaryName(characterForm: characterForm)).userdb",
                isDirectory: true
            )
    }

    public static func rimeSchemaID(characterForm: String) -> String {
        characterForm == "traditional" ? "biline_pinyin_trad" : "biline_pinyin_simp"
    }

    public static func rimeUserDictionaryName(characterForm: String) -> String {
        rimeSchemaID(characterForm: characterForm)
    }

    public static func rimeUserDirectory(inputMethodBundleIdentifier: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Containers/\(inputMethodBundleIdentifier)/Data/Library/Application Support/Rime",
                isDirectory: true
            )
    }

    public static func rimeUserDictionaryURL(inputMethodBundleIdentifier: String) -> URL {
        rimeUserDirectory(inputMethodBundleIdentifier: inputMethodBundleIdentifier)
            .appendingPathComponent("user/biline_pinyin.userdb", isDirectory: true)
    }

    public static func rimeUserDictionaryURL(
        inputMethodBundleIdentifier: String,
        characterForm: String
    ) -> URL {
        rimeUserDirectory(inputMethodBundleIdentifier: inputMethodBundleIdentifier)
            .appendingPathComponent(
                "user/\(rimeUserDictionaryName(characterForm: characterForm)).userdb",
                isDirectory: true
            )
    }
}

public struct BilineDefaultsStore: Sendable {
    public let domain: String

    public init(domain: String) {
        self.domain = domain
    }

    public func string(forKey key: String) -> String? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? String
    }

    public func bool(forKey key: String) -> Bool? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Bool
    }

    public func integer(forKey key: String) -> Int? {
        if let number = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber
        {
            return number.intValue
        }
        return nil
    }

    public func double(forKey key: String) -> Double? {
        if let number = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber
        {
            return number.doubleValue
        }
        return nil
    }

    public func data(forKey key: String) -> Data? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Data
    }

    public func stringArray(forKey key: String) -> [String]? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? [String]
    }

    public func set(_ value: String, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFString, domain as CFString)
    }

    public func set(_ value: Bool, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFBoolean, domain as CFString)
    }

    public func set(_ value: Int, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, NSNumber(value: value), domain as CFString)
    }

    public func set(_ value: Double, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, NSNumber(value: value), domain as CFString)
    }

    public func set(_ value: Data, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFData, domain as CFString)
    }

    public func set(_ value: [String], forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFArray, domain as CFString)
    }

    public func removeValue(forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, nil, domain as CFString)
    }

    public func synchronize() {
        CFPreferencesAppSynchronize(domain as CFString)
    }
}
