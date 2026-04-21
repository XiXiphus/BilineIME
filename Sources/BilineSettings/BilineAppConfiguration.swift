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

    public static func inputMethodRuntimeRimeUserDictionaryURL() -> URL {
        let applicationSupport =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return
            applicationSupport
            .appendingPathComponent("Rime/user/biline_pinyin.userdb", isDirectory: true)
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

    public func set(_ value: String, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFString, domain as CFString)
    }

    public func set(_ value: Bool, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFBoolean, domain as CFString)
    }

    public func set(_ value: Int, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, NSNumber(value: value), domain as CFString)
    }

    public func synchronize() {
        CFPreferencesAppSynchronize(domain as CFString)
    }
}
