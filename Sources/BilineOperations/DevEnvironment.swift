import BilineSettings
import Foundation

public enum BilineInstallSurfaceSelection: String, CaseIterable, Sendable, Codable {
    case user
    case system
    case all

    public var surfaces: [BilineInstallSurface] {
        switch self {
        case .user:
            return [.user]
        case .system:
            return [.system]
        case .all:
            return [.user, .system]
        }
    }

    public var requiresRootPrivileges: Bool {
        surfaces.contains(.system)
    }
}

public struct BilineOperationPaths: Sendable, Equatable {
    public let rootDirectory: URL
    public let derivedData: URL
    public let lsregister: URL
    public let homeDirectory: URL

    public static func defaultDerivedDataURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["DERIVED_DATA"], !override.isEmpty {
            let expanded = (override as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/BilineIME/DerivedData", isDirectory: true)
    }

    public init(
        rootDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        derivedData: URL = BilineOperationPaths.defaultDerivedDataURL(),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        lsregister: URL = URL(
            fileURLWithPath:
                "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
        )
    ) {
        self.rootDirectory = rootDirectory
        self.derivedData = derivedData
        self.homeDirectory = homeDirectory
        self.lsregister = lsregister
    }

    public var devInputMethodInstallURL: URL {
        BilineAppPath.devInputMethodInstallURL(surface: .user, homeDirectory: homeDirectory)
    }

    public var packagedDevInputMethodInstallURL: URL {
        BilineAppPath.devInputMethodInstallURL(surface: .system, homeDirectory: homeDirectory)
    }

    public var devSettingsInstallURL: URL {
        BilineAppPath.devSettingsInstallURL(surface: .user, homeDirectory: homeDirectory)
    }

    public var packagedDevSettingsInstallURL: URL {
        BilineAppPath.devSettingsInstallURL(surface: .system, homeDirectory: homeDirectory)
    }

    public var devBrokerInstallURL: URL {
        BilineAppPath.devBrokerInstallURL(surface: .user, homeDirectory: homeDirectory)
    }

    public var packagedDevBrokerInstallURL: URL {
        BilineAppPath.devBrokerInstallURL(surface: .system, homeDirectory: homeDirectory)
    }

    public var devInputMethodBuildURL: URL {
        derivedData.appendingPathComponent(
            "Build/Products/Debug/BilineIMEDev.app", isDirectory: true)
    }

    public var devSettingsBuildURL: URL {
        derivedData.appendingPathComponent(
            "Build/Products/Debug/BilineSettingsDev.app", isDirectory: true)
    }

    public var devBrokerBuildURL: URL {
        derivedData.appendingPathComponent("Build/Products/Debug/BilineBrokerDev", isDirectory: false)
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
            rootDirectory.appendingPathComponent(
                ".build/xcodebuild-settings/Build/Products/Debug/BilineSettingsDev.app",
                isDirectory: true
            ),
            homeDirectory
                .appendingPathComponent(
                    "Library/Caches/BilineIME/SettingsDerivedData/Build/Products/Debug/BilineSettingsDev.app",
                    isDirectory: true),
            rootDirectory.appendingPathComponent(
                "build/pkgroot/Applications/BilineSettingsDev.app", isDirectory: true),
        ]
    }

    public var preservedDataPaths: [URL] {
        [
            BilineAppPath.credentialFileURL(
                inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
                homeDirectory: homeDirectory),
            BilineAppPath.inputMethodRuntimeCredentialFileURL(homeDirectory: homeDirectory),
            BilineAppPath.rimeUserDictionaryURL(
                inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
                homeDirectory: homeDirectory),
            BilineAppPath.rimeUserDictionaryURL(
                inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
                characterForm: "simplified",
                homeDirectory: homeDirectory),
            BilineAppPath.rimeUserDictionaryURL(
                inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
                characterForm: "traditional",
                homeDirectory: homeDirectory),
            BilineAppPath.inputMethodRuntimeRimeUserDictionaryURL(
                characterForm: "simplified",
                homeDirectory: homeDirectory
            ),
            BilineAppPath.inputMethodRuntimeRimeUserDictionaryURL(
                characterForm: "traditional",
                homeDirectory: homeDirectory
            ),
        ]
    }

    public var deepCleanDataPaths: [URL] {
        [
            BilineAppPath.appContainerURL(
                bundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
                homeDirectory: homeDirectory
            ),
            BilineAppPath.preferenceFileURL(
                domain: BilineAppIdentifier.devInputMethodBundle,
                homeDirectory: homeDirectory
            ),
            BilineAppPath.preferenceFileURL(
                domain: BilineAppIdentifier.devSettingsBundle,
                homeDirectory: homeDirectory
            ),
            BilineAppPath.inputMethodRuntimeCredentialFileURL(homeDirectory: homeDirectory),
            BilineAppPath.inputMethodRuntimeRimeUserDictionaryURL(
                characterForm: "simplified",
                homeDirectory: homeDirectory
            ),
            BilineAppPath.inputMethodRuntimeRimeUserDictionaryURL(
                characterForm: "traditional",
                homeDirectory: homeDirectory
            ),
            homeDirectory.appendingPathComponent(
                "Library/Preferences/\(BilineSharedIdentifier.defaultsSuiteName(for: BilineAppIdentifier.devInputMethodBundle)).plist",
                isDirectory: false
            ),
            homeDirectory.appendingPathComponent(
                "Library/Saved Application State/\(BilineAppIdentifier.devSettingsBundle).savedState",
                isDirectory: true
            ),
        ]
    }

    public func devInputMethodInstallURLs(for selection: BilineInstallSurfaceSelection) -> [URL] {
        selection.surfaces.map {
            BilineAppPath.devInputMethodInstallURL(surface: $0, homeDirectory: homeDirectory)
        }
    }

    public func devSettingsInstallURLs(for selection: BilineInstallSurfaceSelection) -> [URL] {
        selection.surfaces.map {
            BilineAppPath.devSettingsInstallURL(surface: $0, homeDirectory: homeDirectory)
        }
    }

    public func devBrokerInstallURLs(for selection: BilineInstallSurfaceSelection) -> [URL] {
        selection.surfaces.map {
            BilineAppPath.devBrokerInstallURL(surface: $0, homeDirectory: homeDirectory)
        }
    }

    public func devBrokerLaunchAgentURLs(for selection: BilineInstallSurfaceSelection) -> [URL] {
        selection.surfaces.map {
            BilineAppPath.devBrokerLaunchAgentURL(surface: $0, homeDirectory: homeDirectory)
        }
    }
}

public struct DevEnvironmentSnapshot: Sendable, Equatable, Codable {
    public let imeInstallPath: String
    public let imeInstalled: Bool
    public let imeRunning: Bool
    public let settingsInstallPath: String
    public let settingsInstalled: Bool
    public let settingsRunning: Bool
    public let brokerInstallPath: String
    public let brokerInstalled: Bool
    public let brokerRunning: Bool
    public let brokerLaunchAgentPath: String
    public let brokerLaunchAgentInstalled: Bool
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
    public let recommendedAction: LifecycleOperationSpec?
    public let recommendedActionReason: String
    public let inputSourceReadiness: BilineInputSourceReadinessReport

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

    public var recommendedActionText: String {
        recommendedAction?.actionText ?? "无需操作"
    }
}
