import Foundation

public enum BilineTranslationProviderChoice: String, CaseIterable, Sendable, Codable {
    case off
    case aliyun
}

public enum BilineInstallSurface: String, CaseIterable, Sendable {
    case user
    case system
}

public enum BilineDefaultsKey {
    public static let translationProvider = "BilineTranslationProvider"
    public static let alibabaRegionId = "BilineAlibabaRegionId"
    public static let alibabaEndpoint = "BilineAlibabaEndpoint"
    public static let previewEnabled = "BilinePreviewEnabled"
    public static let bilingualModeEnabled = "BilineBilingualModeEnabled"
    public static let didSeedBilingualModeDefault = "BilineDidSeedBilingualModeDefault"
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

public enum BilineSharedIdentifier {
    public static func defaultsSuiteName(for inputMethodBundleIdentifier: String) -> String {
        inputMethodBundleIdentifier == BilineAppIdentifier.devInputMethodBundle
            ? "group.io.github.xixiphus.BilineIME.dev.shared"
            : "group.io.github.xixiphus.BilineIME.shared"
    }

    public static func keychainService(for inputMethodBundleIdentifier: String) -> String {
        inputMethodBundleIdentifier == BilineAppIdentifier.devInputMethodBundle
            ? "io.github.xixiphus.BilineIME.dev.shared.credentials"
            : "io.github.xixiphus.BilineIME.shared.credentials"
    }

    public static func keychainAccessGroup(
        for inputMethodBundleIdentifier: String,
        appIdentifierPrefix: String
    ) -> String {
        let suffix =
            inputMethodBundleIdentifier == BilineAppIdentifier.devInputMethodBundle
            ? "io.github.xixiphus.BilineIME.dev.shared"
            : "io.github.xixiphus.BilineIME.shared"
        return "\(appIdentifierPrefix)\(suffix)"
    }

    public static func brokerMachServiceName(for inputMethodBundleIdentifier: String) -> String {
        inputMethodBundleIdentifier == BilineAppIdentifier.devInputMethodBundle
            ? "io.github.xixiphus.BilineIME.dev.broker"
            : "io.github.xixiphus.BilineIME.broker"
    }

    public static func brokerLaunchAgentLabel(for inputMethodBundleIdentifier: String) -> String {
        brokerMachServiceName(for: inputMethodBundleIdentifier)
    }
}

public enum BilineAppProcessName {
    public static let devInputMethod = "BilineIMEDev"
    public static let devSettings = "BilineSettingsDev"
    public static let devBroker = "BilineBrokerDev"
    public static let releaseInputMethod = "BilineIME"
}

public enum BilineAppPath {
    public static var devInputMethodInstallURL: URL {
        devInputMethodInstallURL(surface: .user)
    }

    public static var devSettingsInstallURL: URL {
        devSettingsInstallURL(surface: .user)
    }

    public static func devInputMethodInstallURL(
        surface: BilineInstallSurface,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        switch surface {
        case .user:
            return homeDirectory
                .appendingPathComponent("Library/Input Methods/BilineIMEDev.app", isDirectory: true)
        case .system:
            return URL(
                fileURLWithPath: "/Library/Input Methods/BilineIMEDev.app", isDirectory: true)
        }
    }

    public static func devSettingsInstallURL(
        surface: BilineInstallSurface,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        switch surface {
        case .user:
            return homeDirectory
                .appendingPathComponent("Applications/BilineSettingsDev.app", isDirectory: true)
        case .system:
            return URL(fileURLWithPath: "/Applications/BilineSettingsDev.app", isDirectory: true)
        }
    }

    public static func appContainerURL(
        bundleIdentifier: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory.appendingPathComponent(
            "Library/Containers/\(bundleIdentifier)",
            isDirectory: true
        )
    }

    public static func applicationSupportDirectory(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    public static func devBrokerInstallURL(
        surface: BilineInstallSurface,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        switch surface {
        case .user:
            return applicationSupportDirectory(homeDirectory: homeDirectory)
                .appendingPathComponent("BilineIME/Broker/BilineBrokerDev", isDirectory: false)
        case .system:
            return URL(fileURLWithPath: "/Library/Application Support/BilineIME/Broker/BilineBrokerDev")
        }
    }

    public static func devBrokerLaunchAgentURL(
        surface: BilineInstallSurface,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let label = BilineSharedIdentifier.brokerLaunchAgentLabel(
            for: BilineAppIdentifier.devInputMethodBundle
        )
        switch surface {
        case .user:
            return homeDirectory
                .appendingPathComponent("Library/LaunchAgents/\(label).plist", isDirectory: false)
        case .system:
            return URL(fileURLWithPath: "/Library/LaunchAgents/\(label).plist")
        }
    }

    public static func preferenceFileURL(
        domain: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory.appendingPathComponent("Library/Preferences/\(domain).plist", isDirectory: false)
    }

    public static func credentialFileURL(
        inputMethodBundleIdentifier: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        appContainerURL(
            bundleIdentifier: inputMethodBundleIdentifier,
            homeDirectory: homeDirectory
        )
            .appendingPathComponent("Data/Library/Application Support/BilineIME", isDirectory: true)
            .appendingPathComponent("alibaba-credentials.json", isDirectory: false)
    }

    public static func inputMethodRuntimeCredentialFileURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        applicationSupportDirectory(homeDirectory: homeDirectory)
            .appendingPathComponent("BilineIME", isDirectory: true)
            .appendingPathComponent("alibaba-credentials.json", isDirectory: false)
    }

    public static func hostSmokeTelemetryFileURL(
        inputMethodBundleIdentifier: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        appContainerURL(
            bundleIdentifier: inputMethodBundleIdentifier,
            homeDirectory: homeDirectory
        )
            .appendingPathComponent("Data/Library/Caches/BilineIME/Smoke", isDirectory: true)
            .appendingPathComponent("telemetry.jsonl", isDirectory: false)
    }

    public static func inputMethodRuntimeRimeUserDictionaryURL(
        characterForm: String = "simplified",
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        applicationSupportDirectory(homeDirectory: homeDirectory)
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

    public static func rimeUserDirectory(
        inputMethodBundleIdentifier: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        appContainerURL(
            bundleIdentifier: inputMethodBundleIdentifier,
            homeDirectory: homeDirectory
        )
            .appendingPathComponent("Data/Library/Application Support/Rime", isDirectory: true)
    }

    public static func rimeUserDictionaryURL(
        inputMethodBundleIdentifier: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        rimeUserDirectory(
            inputMethodBundleIdentifier: inputMethodBundleIdentifier,
            homeDirectory: homeDirectory
        )
            .appendingPathComponent("user/biline_pinyin.userdb", isDirectory: true)
    }

    public static func rimeUserDictionaryURL(
        inputMethodBundleIdentifier: String,
        characterForm: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        rimeUserDirectory(
            inputMethodBundleIdentifier: inputMethodBundleIdentifier,
            homeDirectory: homeDirectory
        )
            .appendingPathComponent(
                "user/\(rimeUserDictionaryName(characterForm: characterForm)).userdb",
                isDirectory: true
            )
    }
}

public struct BilineDefaultsStore: @unchecked Sendable {
    public enum StorageKind: Sendable, Equatable {
        case appDomain
        case sharedSuite(String)
    }

    public let domain: String
    public let storageKind: StorageKind
    private let sharedDefaults: UserDefaults?

    public init(domain: String) {
        self.domain = domain
        self.storageKind = .appDomain
        self.sharedDefaults = nil
    }

    public init(sharedSuiteName: String, logicalDomain: String) {
        self.domain = logicalDomain
        self.storageKind = .sharedSuite(sharedSuiteName)
        self.sharedDefaults = UserDefaults(suiteName: sharedSuiteName)
    }

    public static func shared(
        for inputMethodBundleIdentifier: String
    ) -> BilineDefaultsStore {
        BilineDefaultsStore(
            sharedSuiteName: BilineSharedIdentifier.defaultsSuiteName(
                for: inputMethodBundleIdentifier),
            logicalDomain: inputMethodBundleIdentifier
        )
    }

    public func string(forKey key: String) -> String? {
        if let sharedDefaults {
            return sharedDefaults.string(forKey: key)
        }
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? String
    }

    public func bool(forKey key: String) -> Bool? {
        if let sharedDefaults {
            guard sharedDefaults.object(forKey: key) != nil else { return nil }
            return sharedDefaults.bool(forKey: key)
        }
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Bool
    }

    public func integer(forKey key: String) -> Int? {
        if let sharedDefaults {
            guard sharedDefaults.object(forKey: key) != nil else { return nil }
            return sharedDefaults.integer(forKey: key)
        }
        if let number = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber
        {
            return number.intValue
        }
        return nil
    }

    public func double(forKey key: String) -> Double? {
        if let sharedDefaults {
            guard sharedDefaults.object(forKey: key) != nil else { return nil }
            return sharedDefaults.double(forKey: key)
        }
        if let number = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber
        {
            return number.doubleValue
        }
        return nil
    }

    public func data(forKey key: String) -> Data? {
        if let sharedDefaults {
            return sharedDefaults.data(forKey: key)
        }
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Data
    }

    public func stringArray(forKey key: String) -> [String]? {
        if let sharedDefaults {
            return sharedDefaults.stringArray(forKey: key)
        }
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? [String]
    }

    public func hasValue(forKey key: String) -> Bool {
        if let sharedDefaults {
            return sharedDefaults.object(forKey: key) != nil
        }
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString) != nil
    }

    public func set(_ value: String, forKey key: String) {
        if let sharedDefaults {
            sharedDefaults.set(value, forKey: key)
            return
        }
        CFPreferencesSetAppValue(key as CFString, value as CFString, domain as CFString)
    }

    public func set(_ value: Bool, forKey key: String) {
        if let sharedDefaults {
            sharedDefaults.set(value, forKey: key)
            return
        }
        CFPreferencesSetAppValue(key as CFString, value as CFBoolean, domain as CFString)
    }

    public func set(_ value: Int, forKey key: String) {
        if let sharedDefaults {
            sharedDefaults.set(value, forKey: key)
            return
        }
        CFPreferencesSetAppValue(key as CFString, NSNumber(value: value), domain as CFString)
    }

    public func set(_ value: Double, forKey key: String) {
        if let sharedDefaults {
            sharedDefaults.set(value, forKey: key)
            return
        }
        CFPreferencesSetAppValue(key as CFString, NSNumber(value: value), domain as CFString)
    }

    public func set(_ value: Data, forKey key: String) {
        if let sharedDefaults {
            sharedDefaults.set(value, forKey: key)
            return
        }
        CFPreferencesSetAppValue(key as CFString, value as CFData, domain as CFString)
    }

    public func set(_ value: [String], forKey key: String) {
        if let sharedDefaults {
            sharedDefaults.set(value, forKey: key)
            return
        }
        CFPreferencesSetAppValue(key as CFString, value as CFArray, domain as CFString)
    }

    public func removeValue(forKey key: String) {
        if let sharedDefaults {
            sharedDefaults.removeObject(forKey: key)
            return
        }
        CFPreferencesSetAppValue(key as CFString, nil, domain as CFString)
    }

    public func synchronize() {
        if let sharedDefaults {
            sharedDefaults.synchronize()
            return
        }
        CFPreferencesAppSynchronize(domain as CFString)
    }
}
