import XCTest

@testable import BilineOperations

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
        let releaseURLs: [URL]

        func urlsForApplications(withBundleIdentifier bundleIdentifier: String) -> [URL] {
            switch bundleIdentifier {
            case "io.github.xixiphus.inputmethod.BilineIME.settings.dev":
                return settingsURLs
            case "io.github.xixiphus.inputmethod.BilineIME.dev":
                return imeURLs
            case "io.github.xixiphus.inputmethod.BilineIME":
                return releaseURLs
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
        let plan = DevReinstallPlanner().plan(level: .level1)
        let rendered = plan.rendered

        XCTAssertFalse(plan.requiresRebootBeforeInstall)
        XCTAssertTrue(rendered.contains("BilineIMEDev.app"))
        XCTAssertTrue(rendered.contains("BilineSettingsDev.app"))
        XCTAssertTrue(
            rendered.contains("Preserve Alibaba credentials, Rime userdb, and Biline defaults"))
        XCTAssertTrue(rendered.contains("manualHostGate"))
        XCTAssertFalse(rendered.contains("IntlDataCache"))
        XCTAssertFalse(rendered.contains("lsregister -delete"))
    }

    func testLevel2RepairsLocalInputStateBeforeReinstallAndRequiresReboot() {
        let plan = DevReinstallPlanner().plan(level: .level2)
        let rendered = plan.rendered

        XCTAssertTrue(plan.requiresRebootBeforeInstall)
        XCTAssertTrue(
            rendered.contains("Remove dev IME, dev Settings App, and release IME app bundles only"))
        XCTAssertTrue(rendered.contains("Prune Biline HIToolbox state and clear IntlDataCache"))
        XCTAssertTrue(rendered.contains("Reboot is required before reinstalling dev apps"))
        XCTAssertTrue(
            rendered.contains("Preserve Alibaba credentials, Rime userdb, and Biline defaults"))
        XCTAssertFalse(rendered.contains("Build BilineIMEDev"))
        XCTAssertFalse(rendered.contains("lsregister -delete"))
    }

    func testLevel3ResetsLaunchServicesAndRequiresReboot() {
        let plan = DevReinstallPlanner().plan(level: .level3)
        let rendered = plan.rendered

        XCTAssertTrue(plan.requiresRebootBeforeInstall)
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
            recommendedRepairLevel: 3
        )

        XCTAssertTrue(snapshot.settingsInstalledAtStablePath)
        XCTAssertTrue(snapshot.defaultSettingsAtStablePath)
        XCTAssertTrue(snapshot.imeInstalledAtStablePath)
        XCTAssertEqual(snapshot.recommendedRepairText, "Level 3")
    }

    func testDuplicateSettingsRegistrationsDoNotEscalateWhenDefaultPathIsStable() throws {
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
                defaultSettingsURL: settingsInstallURL,
                imeURLs: [imeInstallURL],
                releaseURLs: []
            )
        )

        let snapshot = diagnostics.snapshot()

        XCTAssertEqual(snapshot.settingsLaunchServicesPathCount, 2)
        XCTAssertEqual(snapshot.defaultSettingsApplicationPath, settingsInstallURL.path)
        XCTAssertTrue(snapshot.defaultSettingsAtStablePath)
        XCTAssertEqual(snapshot.recommendedRepairLevel, 0)
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
                imeURLs: [imeInstallURL],
                releaseURLs: []
            )
        )

        let snapshot = diagnostics.snapshot()

        XCTAssertEqual(snapshot.defaultSettingsApplicationPath, legacySettingsURL.path)
        XCTAssertFalse(snapshot.defaultSettingsAtStablePath)
        XCTAssertEqual(snapshot.recommendedRepairLevel, 2)
    }
}
