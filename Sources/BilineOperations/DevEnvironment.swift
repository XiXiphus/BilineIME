import BilineSettings
import Foundation

public enum BilineOperationLevel: Int, CaseIterable, Sendable {
    case level1 = 1
    case level2 = 2
    case level3 = 3

    public init?(rawArgument: String) {
        guard let value = Int(rawArgument) else { return nil }
        self.init(rawValue: value)
    }

    public var requiresReboot: Bool {
        rawValue >= 2
    }
}

public struct BilineOperationPaths: Sendable, Equatable {
    public let rootDirectory: URL
    public let derivedData: URL
    public let lsregister: URL

    public init(
        rootDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        derivedData: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/BilineIME/DerivedData", isDirectory: true),
        lsregister: URL = URL(
            fileURLWithPath:
                "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
        )
    ) {
        self.rootDirectory = rootDirectory
        self.derivedData = derivedData
        self.lsregister = lsregister
    }

    public var devInputMethodInstallURL: URL {
        BilineAppPath.devInputMethodInstallURL
    }

    public var devSettingsInstallURL: URL {
        BilineAppPath.devSettingsInstallURL
    }

    public var devInputMethodBuildURL: URL {
        derivedData.appendingPathComponent(
            "Build/Products/Debug/BilineIMEDev.app", isDirectory: true)
    }

    public var devSettingsBuildURL: URL {
        derivedData.appendingPathComponent(
            "Build/Products/Debug/BilineSettingsDev.app", isDirectory: true)
    }

    public var legacyDevInputMethodURLs: [URL] {
        [
            devInputMethodBuildURL,
            rootDirectory.appendingPathComponent(
                "build/DerivedData/Build/Products/Debug/BilineIMEDev.app", isDirectory: true),
            rootDirectory.appendingPathComponent(
                "build/pkgroot/Library/Input Methods/BilineIMEDev.app", isDirectory: true),
        ]
    }

    public var legacyDevSettingsURLs: [URL] {
        [
            devSettingsBuildURL,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Library/Caches/BilineIME/SettingsDerivedData/Build/Products/Debug/BilineSettingsDev.app",
                    isDirectory: true),
        ]
    }

    public var preservedDataPaths: [URL] {
        [
            BilineAppPath.credentialFileURL(
                inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle),
            BilineAppPath.rimeUserDictionaryURL(
                inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle),
            BilineAppPath.rimeUserDictionaryURL(
                inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
                characterForm: "simplified"),
            BilineAppPath.rimeUserDictionaryURL(
                inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
                characterForm: "traditional"),
        ]
    }
}

public struct DevEnvironmentSnapshot: Sendable, Equatable {
    public let imeInstallPath: String
    public let imeInstalled: Bool
    public let imeRunning: Bool
    public let settingsInstallPath: String
    public let settingsInstalled: Bool
    public let settingsRunning: Bool
    public let settingsLaunchServicesPathCount: Int
    public let defaultSettingsApplicationPath: String?
    public let imeLaunchServicesPathCount: Int
    public let hasStaleLaunchServicesEntry: Bool
    public let hasBilineHitoolboxState: Bool
    public let currentInputSource: String
    public let credentialFilePath: String
    public let credentialFileComplete: Bool
    public let rimeUserDictionaryPath: String
    public let rimeUserDictionaryExists: Bool
    public let characterFormDefaultsRawValue: String
    public let punctuationFormDefaultsRawValue: String
    public let rimeSchemaID: String
    public let rimeUserDictionaryName: String
    public let rimeRuntimeResourceCount: Int
    public let recommendedRepairLevel: Int

    public var settingsInstalledAtStablePath: Bool {
        settingsInstalled && settingsInstallPath.hasSuffix("/Applications/BilineSettingsDev.app")
    }

    public var defaultSettingsAtStablePath: Bool {
        guard let defaultSettingsApplicationPath else { return false }
        return defaultSettingsApplicationPath.hasSuffix("/Applications/BilineSettingsDev.app")
    }

    public var imeInstalledAtStablePath: Bool {
        imeInstalled && imeInstallPath.hasSuffix("/Library/Input Methods/BilineIMEDev.app")
    }

    public var recommendedRepairText: String {
        recommendedRepairLevel == 0 ? "无需修复" : "Level \(recommendedRepairLevel)"
    }
}
