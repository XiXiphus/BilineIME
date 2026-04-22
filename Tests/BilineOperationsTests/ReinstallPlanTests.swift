import XCTest

@testable import BilineOperations
import BilineSettings

final class ReinstallPlanTests: XCTestCase {
    private struct MockRunner: CommandRunning {
        let currentInputSource: String

        func run(_ executable: String, _ arguments: [String], allowFailure: Bool) throws
            -> CommandResult
        {
            if executable == "/usr/bin/pgrep" {
                return CommandResult(status: 1, output: "", errorOutput: "")
            }
            if executable.hasSuffix("scripts/select-input-source.sh"), arguments == ["current"] {
                return CommandResult(status: 0, output: currentInputSource, errorOutput: "")
            }
            return CommandResult(status: 0, output: "", errorOutput: "")
        }

        func runShell(_ command: String, allowFailure: Bool) throws -> CommandResult {
            return CommandResult(status: 0, output: "", errorOutput: "")
        }
    }

    private struct MockWorkspace: ApplicationWorkspaceQuerying {
        let settingsURLs: [URL]
        let defaultSettingsURL: URL?
        let imeURLs: [URL]

        func urlsForApplications(withBundleIdentifier bundleIdentifier: String) -> [URL] {
            switch bundleIdentifier {
            case "io.github.xixiphus.inputmethod.BilineIME.settings.dev":
                return settingsURLs
            case "io.github.xixiphus.inputmethod.BilineIME.dev":
                return imeURLs
            default:
                return []
            }
        }

        func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL? {
            bundleIdentifier == "io.github.xixiphus.inputmethod.BilineIME.settings.dev"
                ? defaultSettingsURL : nil
        }
    }

    func testLevel1ReinstallsBothDevAppsAndPreservesUserData() {
        let plan = LifecycleOperationPlanner().plan(.install(scope: .user))
        let rendered = plan.rendered

        XCTAssertEqual(plan.spec, .install(scope: .user))
        XCTAssertFalse(plan.spec.requiresReboot)
        XCTAssertTrue(rendered.contains("BilineIMEDev.app"))
        XCTAssertTrue(rendered.contains("BilineSettingsDev.app"))
        XCTAssertTrue(rendered.contains("BilineBrokerDev"))
        XCTAssertTrue(
            rendered.contains("Preserve Alibaba credentials, Rime userdb, and Biline defaults"))
        XCTAssertTrue(rendered.contains("manualHostGate"))
        XCTAssertFalse(rendered.contains("IntlDataCache"))
        XCTAssertFalse(rendered.contains("lsregister -delete"))
    }

    func testLevel2RepairsLocalInputStateBeforeReinstallAndRequiresReboot() {
        let plan = LifecycleOperationPlanner().plan(.reset(scope: .all, depth: .cachePrune))
        let rendered = plan.rendered

        XCTAssertEqual(plan.spec, .reset(scope: .all, depth: .cachePrune))
        XCTAssertTrue(plan.spec.requiresReboot)
        XCTAssertTrue(rendered.contains("Remove installed dev bundles"))
        XCTAssertTrue(rendered.contains("Prune Biline HIToolbox state"))
        XCTAssertTrue(rendered.contains("Clear IntlDataCache"))
        XCTAssertTrue(rendered.contains("Reboot is required before reinstalling dev apps"))
        XCTAssertTrue(
            rendered.contains("Preserve Alibaba credentials, Rime userdb, and Biline defaults"))
        XCTAssertFalse(rendered.contains("Build BilineIMEDev"))
        XCTAssertFalse(rendered.contains("lsregister -delete"))
    }

    func testLevel3ResetsLaunchServicesAndRequiresReboot() {
        let plan = LifecycleOperationPlanner().plan(.reset(scope: .all, depth: .launchServicesReset))
        let rendered = plan.rendered

        XCTAssertEqual(plan.spec, .reset(scope: .all, depth: .launchServicesReset))
        XCTAssertTrue(plan.spec.requiresReboot)
        XCTAssertTrue(
            rendered.contains("Reset the LaunchServices database with lsregister -delete"))
        XCTAssertTrue(rendered.contains("Reboot is required before reinstalling dev apps"))
        XCTAssertTrue(
            rendered.contains("Preserve Alibaba credentials, Rime userdb, and Biline defaults"))
    }

    func testSnapshotRecommendationPrefersHighestRepairSignal() {
        let snapshot = DevEnvironmentSnapshot(
            imeInstallPath: "/Users/example/Library/Input Methods/BilineIMEDev.app",
            imeInstalled: true,
            imeRunning: false,
            settingsInstallPath: "/Users/example/Applications/BilineSettingsDev.app",
            settingsInstalled: true,
            settingsRunning: false,
            brokerInstallPath: "/Users/example/Library/Application Support/BilineIME/Broker/BilineBrokerDev",
            brokerInstalled: true,
            brokerRunning: false,
            brokerLaunchAgentPath: "/Users/example/Library/LaunchAgents/io.github.xixiphus.BilineIME.dev.broker.plist",
            brokerLaunchAgentInstalled: true,
            settingsLaunchServicesPathCount: 2,
            defaultSettingsApplicationPath: "/Users/example/Applications/BilineSettingsDev.app",
            imeLaunchServicesPathCount: 1,
            hasStaleLaunchServicesEntry: true,
            hasBilineHitoolboxState: true,
            currentInputSource: "com.apple.keylayout.ABC",
            credentialFilePath: "/tmp/alibaba-credentials.json",
            credentialFileComplete: true,
            rimeUserDictionaryPath: "/tmp/biline_pinyin_simp.userdb",
            rimeUserDictionaryExists: true,
            characterFormDefaultsRawValue: "simplified",
            punctuationFormDefaultsRawValue: "fullwidth",
            rimeSchemaID: "biline_pinyin_simp",
            rimeUserDictionaryName: "biline_pinyin_simp",
            rimeRuntimeResourceCount: 9,
            recommendedAction: .reset(scope: .all, depth: .launchServicesReset),
            recommendedActionReason: "LaunchServices still references stale Biline paths.",
            inputSourceReadiness: BilineInputSourceReadinessReport(
                state: .ready,
                inputSourceID: "io.github.xixiphus.inputmethod.BilineIME.dev.pinyin",
                bundleIdentifier: "io.github.xixiphus.inputmethod.BilineIME.dev",
                bundleInstalled: true,
                snapshot: BilineInputSourceSnapshot(
                    id: "io.github.xixiphus.inputmethod.BilineIME.dev.pinyin",
                    localizedName: "BilineIME Dev",
                    enabled: true,
                    selectable: true,
                    selected: true
                ),
                currentInputSourceID: "io.github.xixiphus.inputmethod.BilineIME.dev.pinyin",
                summary: "BilineIME Dev is enabled, selectable, and currently active.",
                remediation: []
            )
        )

        XCTAssertTrue(snapshot.settingsInstalledAtStablePath)
        XCTAssertTrue(snapshot.defaultSettingsAtStablePath)
        XCTAssertTrue(snapshot.imeInstalledAtStablePath)
        XCTAssertEqual(snapshot.recommendedActionText, "reset(scope: all, depth: launch-services-reset)")
    }

    func testDuplicateSettingsRegistrationsDoNotEscalateWhenDefaultPathIsStable() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let derivedDataURL = rootURL.appendingPathComponent("DerivedData", isDirectory: true)
        let settingsInstallURL = rootURL.appendingPathComponent(
            "Applications/BilineSettingsDev.app", isDirectory: true)
        let imeInstallURL = rootURL.appendingPathComponent(
            "Library/Input Methods/BilineIMEDev.app", isDirectory: true)
        let brokerInstallURL = rootURL.appendingPathComponent(
            "Library/Application Support/BilineIME/Broker/BilineBrokerDev", isDirectory: false)
        let brokerLaunchAgentURL = rootURL.appendingPathComponent(
            "Library/LaunchAgents/io.github.xixiphus.BilineIME.dev.broker.plist", isDirectory: false)
        let legacySettingsURL = derivedDataURL.appendingPathComponent(
            "Build/Products/Debug/BilineSettingsDev.app", isDirectory: true)

        try fileManager.createDirectory(at: settingsInstallURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imeInstallURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: legacySettingsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: brokerInstallURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: brokerLaunchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("broker".utf8).write(to: brokerInstallURL)
        try Data("launch-agent".utf8).write(to: brokerLaunchAgentURL)

        defer { try? fileManager.removeItem(at: rootURL) }

        let diagnostics = DevEnvironmentDiagnostics(
            paths: BilineOperationPaths(
                rootDirectory: rootURL,
                derivedData: derivedDataURL,
                homeDirectory: rootURL
            ),
            runner: MockRunner(currentInputSource: "io.github.xixiphus.inputmethod.BilineIME.dev"),
            fileManager: fileManager,
            workspace: MockWorkspace(
                settingsURLs: [settingsInstallURL, legacySettingsURL],
                defaultSettingsURL: settingsInstallURL,
                imeURLs: [imeInstallURL]
            )
        )

        let snapshot = diagnostics.snapshot()

        XCTAssertEqual(snapshot.settingsLaunchServicesPathCount, 2)
        XCTAssertEqual(snapshot.defaultSettingsApplicationPath, settingsInstallURL.path)
        XCTAssertTrue(snapshot.defaultSettingsAtStablePath)
        XCTAssertNil(snapshot.recommendedAction)
    }

    func testDuplicateSettingsRegistrationsEscalateWhenDefaultPathIsWrong() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let derivedDataURL = rootURL.appendingPathComponent("DerivedData", isDirectory: true)
        let settingsInstallURL = rootURL.appendingPathComponent(
            "Applications/BilineSettingsDev.app", isDirectory: true)
        let imeInstallURL = rootURL.appendingPathComponent(
            "Library/Input Methods/BilineIMEDev.app", isDirectory: true)
        let legacySettingsURL = derivedDataURL.appendingPathComponent(
            "Build/Products/Debug/BilineSettingsDev.app", isDirectory: true)

        try fileManager.createDirectory(at: settingsInstallURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imeInstallURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: legacySettingsURL, withIntermediateDirectories: true)

        defer { try? fileManager.removeItem(at: rootURL) }

        let diagnostics = DevEnvironmentDiagnostics(
            paths: BilineOperationPaths(rootDirectory: rootURL, derivedData: derivedDataURL),
            runner: MockRunner(currentInputSource: "io.github.xixiphus.inputmethod.BilineIME.dev"),
            fileManager: fileManager,
            workspace: MockWorkspace(
                settingsURLs: [settingsInstallURL, legacySettingsURL],
                defaultSettingsURL: legacySettingsURL,
                imeURLs: [imeInstallURL]
            )
        )

        let snapshot = diagnostics.snapshot()

        XCTAssertEqual(snapshot.defaultSettingsApplicationPath, legacySettingsURL.path)
        XCTAssertFalse(snapshot.defaultSettingsAtStablePath)
        XCTAssertEqual(snapshot.recommendedAction, .reset(scope: .all, depth: .cachePrune))
    }

    func testSnapshotResolvesInstalledPathsFromLaunchServicesOutsideDefaultHome() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let homeURL = rootURL.appendingPathComponent("home", isDirectory: true)
        let derivedDataURL = rootURL.appendingPathComponent("DerivedData", isDirectory: true)
        let settingsInstallURL = rootURL.appendingPathComponent(
            "Applications/BilineSettingsDev.app", isDirectory: true)
        let imeInstallURL = rootURL.appendingPathComponent(
            "Library/Input Methods/BilineIMEDev.app", isDirectory: true)

        try fileManager.createDirectory(at: homeURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: settingsInstallURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imeInstallURL, withIntermediateDirectories: true)

        defer { try? fileManager.removeItem(at: rootURL) }

        let diagnostics = DevEnvironmentDiagnostics(
            paths: BilineOperationPaths(
                rootDirectory: rootURL,
                derivedData: derivedDataURL,
                homeDirectory: homeURL
            ),
            runner: MockRunner(currentInputSource: "io.github.xixiphus.inputmethod.BilineIME.dev"),
            fileManager: fileManager,
            workspace: MockWorkspace(
                settingsURLs: [settingsInstallURL],
                defaultSettingsURL: settingsInstallURL,
                imeURLs: [imeInstallURL]
            )
        )

        let snapshot = diagnostics.snapshot()

        XCTAssertTrue(
            [settingsInstallURL.path, "/Applications/BilineSettingsDev.app"].contains(
                snapshot.settingsInstallPath
            )
        )
        XCTAssertTrue(
            [imeInstallURL.path, "/Library/Input Methods/BilineIMEDev.app"].contains(
                snapshot.imeInstallPath
            )
        )
        XCTAssertTrue(snapshot.settingsInstalled)
        XCTAssertTrue(snapshot.imeInstalled)
        XCTAssertTrue(snapshot.settingsInstalledAtStablePath)
        XCTAssertTrue(snapshot.imeInstalledAtStablePath)
    }

    func testDeepCleanUninstallRemovesUserInstallAndLocalData() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let homeURL = rootURL.appendingPathComponent("home", isDirectory: true)
        let derivedDataURL = rootURL.appendingPathComponent("DerivedData", isDirectory: true)
        let paths = BilineOperationPaths(
            rootDirectory: rootURL,
            derivedData: derivedDataURL,
            homeDirectory: homeURL
        )

        try fileManager.createDirectory(at: homeURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: paths.devInputMethodInstallURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: paths.devSettingsInstallURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: paths.devBrokerInstallURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("broker".utf8).write(to: paths.devBrokerInstallURL)
        try fileManager.createDirectory(
            at: paths.devBrokerLaunchAgentURLs(for: .user).first!.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("launch-agent".utf8).write(to: paths.devBrokerLaunchAgentURLs(for: .user).first!)
        try fileManager.createDirectory(
            at: BilineAppPath.appContainerURL(
                bundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
                homeDirectory: homeURL
            ),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: BilineAppPath.inputMethodRuntimeRimeUserDictionaryURL(
                characterForm: "simplified",
                homeDirectory: homeURL
            ),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: BilineAppPath.inputMethodRuntimeRimeUserDictionaryURL(
                characterForm: "traditional",
                homeDirectory: homeURL
            ),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: homeURL.appendingPathComponent(
                "Library/Saved Application State/\(BilineAppIdentifier.devSettingsBundle).savedState",
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )

        let defaultsURL = BilineAppPath.preferenceFileURL(
            domain: BilineAppIdentifier.devInputMethodBundle,
            homeDirectory: homeURL
        )
        try fileManager.createDirectory(
            at: defaultsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("defaults".utf8).write(to: defaultsURL)

        let settingsDefaultsURL = BilineAppPath.preferenceFileURL(
            domain: BilineAppIdentifier.devSettingsBundle,
            homeDirectory: homeURL
        )
        try Data("settings-defaults".utf8).write(to: settingsDefaultsURL)

        let credentialURL = BilineAppPath.inputMethodRuntimeCredentialFileURL(homeDirectory: homeURL)
        try fileManager.createDirectory(
            at: credentialURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("credentials".utf8).write(to: credentialURL)

        defer { try? fileManager.removeItem(at: rootURL) }

        let executor = LifecycleOperationExecutor(
            paths: paths,
            runner: MockRunner(currentInputSource: "com.apple.keylayout.ABC"),
            fileManager: fileManager
        )

        let output = try executor.apply(
            .prepareRelease(scope: .user),
            confirmed: true
        )

        XCTAssertTrue(output.contains("ready_for_release_install=true"))
        XCTAssertFalse(fileManager.fileExists(atPath: paths.devInputMethodInstallURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: paths.devSettingsInstallURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: paths.devBrokerInstallURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: paths.devBrokerLaunchAgentURLs(for: .user).first!.path))
        for url in paths.deepCleanDataPaths {
            XCTAssertFalse(fileManager.fileExists(atPath: url.path), "Expected \(url.path) to be removed")
        }
    }

    func testSystemSurfaceUninstallRequiresRootPrivileges() {
        let executor = LifecycleOperationExecutor(
            runner: MockRunner(currentInputSource: "com.apple.keylayout.ABC")
        )

        XCTAssertThrowsError(
            try executor.apply(.remove(scope: .system, dataPolicy: .preserve), confirmed: true)
        ) { error in
            guard case BilineOperationError.privilegedActionRequiresRoot = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
