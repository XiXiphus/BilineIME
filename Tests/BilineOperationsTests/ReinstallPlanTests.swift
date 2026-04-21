import XCTest

@testable import BilineOperations

final class ReinstallPlanTests: XCTestCase {
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
            imeLaunchServicesPathCount: 1,
            hasStaleLaunchServicesEntry: true,
            hasBilineHitoolboxState: true,
            currentInputSource: "com.apple.keylayout.ABC",
            credentialFilePath: "/tmp/alibaba-credentials.json",
            credentialFileComplete: true,
            rimeUserDictionaryPath: "/tmp/biline_pinyin.userdb",
            rimeUserDictionaryExists: true,
            characterFormDefaultsRawValue: "simplified",
            recommendedRepairLevel: 3
        )

        XCTAssertTrue(snapshot.settingsInstalledAtStablePath)
        XCTAssertTrue(snapshot.imeInstalledAtStablePath)
        XCTAssertEqual(snapshot.recommendedRepairText, "Level 3")
    }
}
