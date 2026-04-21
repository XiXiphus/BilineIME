import AppKit
import BilineSettings
import Foundation

public struct DevEnvironmentDiagnostics {
    public let paths: BilineOperationPaths
    public let runner: any CommandRunning
    private let fileManager: FileManager

    public init(
        paths: BilineOperationPaths = BilineOperationPaths(),
        runner: any CommandRunning = ProcessCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.paths = paths
        self.runner = runner
        self.fileManager = fileManager
    }

    public func snapshot() -> DevEnvironmentSnapshot {
        let settingsURLs = NSWorkspace.shared.urlsForApplications(
            withBundleIdentifier: BilineAppIdentifier.devSettingsBundle)
        let imeURLs = NSWorkspace.shared.urlsForApplications(
            withBundleIdentifier: BilineAppIdentifier.devInputMethodBundle)
        let releaseURLs = NSWorkspace.shared.urlsForApplications(
            withBundleIdentifier: BilineAppIdentifier.releaseInputMethodBundle)
        let hitoolbox = readHitoolboxState()
        let credentialStatus = BilineCredentialFileStore(
            inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle
        ).status()
        let currentSource =
            (try? runner.run(
                paths.rootDirectory.appendingPathComponent("scripts/select-input-source.sh").path,
                ["current"],
                allowFailure: true
            ).output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""

        let settingsPathCount = settingsURLs.count
        let imePathCount = imeURLs.count
        let staleLS = (settingsURLs + imeURLs + releaseURLs).contains {
            !fileManager.fileExists(atPath: $0.path)
        }
        let hasHitoolbox = hitoolbox.contains("io.github.xixiphus.inputmethod.BilineIME")
        let rimeUserDB = BilineAppPath.rimeUserDictionaryURL(
            inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle)
        let characterFormRaw =
            BilineDefaultsStore(domain: BilineAppIdentifier.devInputMethodBundle)
            .string(forKey: BilineDefaultsKey.characterForm) ?? ""

        return DevEnvironmentSnapshot(
            imeInstallPath: paths.devInputMethodInstallURL.path,
            imeInstalled: fileManager.fileExists(atPath: paths.devInputMethodInstallURL.path),
            imeRunning: isProcessRunning(BilineAppProcessName.devInputMethod),
            settingsInstallPath: paths.devSettingsInstallURL.path,
            settingsInstalled: fileManager.fileExists(atPath: paths.devSettingsInstallURL.path),
            settingsRunning: isProcessRunning(BilineAppProcessName.devSettings),
            settingsLaunchServicesPathCount: settingsPathCount,
            imeLaunchServicesPathCount: imePathCount,
            hasStaleLaunchServicesEntry: staleLS,
            hasBilineHitoolboxState: hasHitoolbox,
            currentInputSource: currentSource,
            credentialFilePath: credentialStatus.fileURL.path,
            credentialFileComplete: credentialStatus.isComplete,
            rimeUserDictionaryPath: rimeUserDB.path,
            rimeUserDictionaryExists: fileManager.fileExists(atPath: rimeUserDB.path),
            characterFormDefaultsRawValue: characterFormRaw,
            recommendedRepairLevel: recommendedRepairLevel(
                settingsPathCount: settingsPathCount,
                imePathCount: imePathCount,
                staleLS: staleLS,
                hasHitoolbox: hasHitoolbox,
                imeInstalled: fileManager.fileExists(atPath: paths.devInputMethodInstallURL.path),
                settingsInstalled: fileManager.fileExists(atPath: paths.devSettingsInstallURL.path)
            )
        )
    }

    public func diagnosticReport() -> String {
        let snapshot = snapshot()
        return [
            "== Biline Dev Lifecycle ==",
            "ime_install=\(snapshot.imeInstallPath)",
            "ime_installed=\(snapshot.imeInstalled)",
            "ime_running=\(snapshot.imeRunning)",
            "settings_install=\(snapshot.settingsInstallPath)",
            "settings_installed=\(snapshot.settingsInstalled)",
            "settings_running=\(snapshot.settingsRunning)",
            "settings_launchservices_path_count=\(snapshot.settingsLaunchServicesPathCount)",
            "ime_launchservices_path_count=\(snapshot.imeLaunchServicesPathCount)",
            "stale_launchservices_entry=\(snapshot.hasStaleLaunchServicesEntry)",
            "hitoolbox_biline_state=\(snapshot.hasBilineHitoolboxState)",
            "current_input_source=\(snapshot.currentInputSource)",
            "credential_file=\(snapshot.credentialFilePath)",
            "credential_file_complete=\(snapshot.credentialFileComplete)",
            "rime_userdb=\(snapshot.rimeUserDictionaryPath)",
            "rime_userdb_exists=\(snapshot.rimeUserDictionaryExists)",
            "character_form_default=\(snapshot.characterFormDefaultsRawValue.isEmpty ? "<unset>" : snapshot.characterFormDefaultsRawValue)",
            "recommended_repair=\(snapshot.recommendedRepairText)",
            "manual_host_gate=required",
        ].joined(separator: "\n")
    }

    private func readHitoolboxState() -> String {
        let command = """
            defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null || true
            defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null || true
            defaults read com.apple.HIToolbox AppleInputSourceHistory 2>/dev/null || true
            """
        return (try? runner.runShell(command, allowFailure: true).output) ?? ""
    }

    private func isProcessRunning(_ processName: String) -> Bool {
        ((try? runner.run("/usr/bin/pgrep", ["-x", processName], allowFailure: true).status) ?? 1)
            == 0
    }

    private func recommendedRepairLevel(
        settingsPathCount: Int,
        imePathCount: Int,
        staleLS: Bool,
        hasHitoolbox: Bool,
        imeInstalled: Bool,
        settingsInstalled: Bool
    ) -> Int {
        if staleLS { return 3 }
        if settingsPathCount > 1 || imePathCount > 1 { return 2 }
        if hasHitoolbox && !imeInstalled { return 2 }
        if settingsPathCount == 0 || imePathCount == 0 || !imeInstalled || !settingsInstalled {
            return 1
        }
        return 0
    }
}
