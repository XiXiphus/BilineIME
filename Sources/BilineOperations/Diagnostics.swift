import AppKit
import BilineSettings
import Foundation

public protocol ApplicationWorkspaceQuerying {
    func urlsForApplications(withBundleIdentifier bundleIdentifier: String) -> [URL]
    func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL?
}

public struct SystemWorkspaceQuery: ApplicationWorkspaceQuerying {
    public init() {}

    public func urlsForApplications(withBundleIdentifier bundleIdentifier: String) -> [URL] {
        NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleIdentifier)
    }

    public func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }
}

public struct DevEnvironmentDiagnostics {
    public let paths: BilineOperationPaths
    public let runner: any CommandRunning
    private let fileManager: FileManager
    private let workspace: any ApplicationWorkspaceQuerying

    public init(
        paths: BilineOperationPaths = BilineOperationPaths(),
        runner: any CommandRunning = ProcessCommandRunner(),
        fileManager: FileManager = .default,
        workspace: any ApplicationWorkspaceQuerying = SystemWorkspaceQuery()
    ) {
        self.paths = paths
        self.runner = runner
        self.fileManager = fileManager
        self.workspace = workspace
    }

    public func snapshot() -> DevEnvironmentSnapshot {
        let settingsURLs = workspace.urlsForApplications(
            withBundleIdentifier: BilineAppIdentifier.devSettingsBundle)
        let defaultSettingsURL = workspace.urlForApplication(
            withBundleIdentifier: BilineAppIdentifier.devSettingsBundle)
        let imeURLs = workspace.urlsForApplications(
            withBundleIdentifier: BilineAppIdentifier.devInputMethodBundle)
        let releaseURLs = workspace.urlsForApplications(
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
        let characterFormRaw =
            BilineDefaultsStore(domain: BilineAppIdentifier.devInputMethodBundle)
            .string(forKey: BilineDefaultsKey.characterForm) ?? ""
        let punctuationFormRaw =
            BilineDefaultsStore(domain: BilineAppIdentifier.devInputMethodBundle)
            .string(forKey: BilineDefaultsKey.punctuationForm) ?? ""
        let resolvedCharacterForm = characterFormRaw.isEmpty ? "simplified" : characterFormRaw
        let schemaID = BilineAppPath.rimeSchemaID(characterForm: resolvedCharacterForm)
        let userDictionaryName = BilineAppPath.rimeUserDictionaryName(
            characterForm: resolvedCharacterForm)
        let activeRimeUserDB = BilineAppPath.rimeUserDictionaryURL(
            inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
            characterForm: resolvedCharacterForm
        )
        let runtimeResourceURL = paths.devInputMethodInstallURL
            .appendingPathComponent("Contents/Resources/RimeRuntime/rime-data", isDirectory: true)

        return DevEnvironmentSnapshot(
            imeInstallPath: paths.devInputMethodInstallURL.path,
            imeInstalled: fileManager.fileExists(atPath: paths.devInputMethodInstallURL.path),
            imeRunning: isProcessRunning(BilineAppProcessName.devInputMethod),
            settingsInstallPath: paths.devSettingsInstallURL.path,
            settingsInstalled: fileManager.fileExists(atPath: paths.devSettingsInstallURL.path),
            settingsRunning: isProcessRunning(BilineAppProcessName.devSettings),
            settingsLaunchServicesPathCount: settingsPathCount,
            defaultSettingsApplicationPath: defaultSettingsURL?.path,
            imeLaunchServicesPathCount: imePathCount,
            hasStaleLaunchServicesEntry: staleLS,
            hasBilineHitoolboxState: hasHitoolbox,
            currentInputSource: currentSource,
            credentialFilePath: credentialStatus.fileURL.path,
            credentialFileComplete: credentialStatus.isComplete,
            rimeUserDictionaryPath: activeRimeUserDB.path,
            rimeUserDictionaryExists: fileManager.fileExists(atPath: activeRimeUserDB.path),
            characterFormDefaultsRawValue: characterFormRaw,
            punctuationFormDefaultsRawValue: punctuationFormRaw,
            rimeSchemaID: schemaID,
            rimeUserDictionaryName: userDictionaryName,
            rimeRuntimeResourceCount: resourceCount(at: runtimeResourceURL),
            recommendedRepairLevel: recommendedRepairLevel(
                settingsPathCount: settingsPathCount,
                defaultSettingsAtStablePath: defaultSettingsURL?.path.hasSuffix(
                    "/Applications/BilineSettingsDev.app") == true,
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
            "settings_launchservices_default_path=\(snapshot.defaultSettingsApplicationPath ?? "<none>")",
            "settings_launchservices_default_stable=\(snapshot.defaultSettingsAtStablePath)",
            "ime_launchservices_path_count=\(snapshot.imeLaunchServicesPathCount)",
            "stale_launchservices_entry=\(snapshot.hasStaleLaunchServicesEntry)",
            "hitoolbox_biline_state=\(snapshot.hasBilineHitoolboxState)",
            "current_input_source=\(snapshot.currentInputSource)",
            "credential_file=\(snapshot.credentialFilePath)",
            "credential_file_complete=\(snapshot.credentialFileComplete)",
            "rime_userdb=\(snapshot.rimeUserDictionaryPath)",
            "rime_userdb_exists=\(snapshot.rimeUserDictionaryExists)",
            "character_form=\(snapshot.characterFormDefaultsRawValue.isEmpty ? "simplified" : snapshot.characterFormDefaultsRawValue)",
            "character_form_default=\(snapshot.characterFormDefaultsRawValue.isEmpty ? "<unset>" : snapshot.characterFormDefaultsRawValue)",
            "punctuation_form=\(snapshot.punctuationFormDefaultsRawValue.isEmpty ? "fullwidth" : snapshot.punctuationFormDefaultsRawValue)",
            "punctuation_form_default=\(snapshot.punctuationFormDefaultsRawValue.isEmpty ? "<unset>" : snapshot.punctuationFormDefaultsRawValue)",
            "rime_schema_id=\(snapshot.rimeSchemaID)",
            "rime_userdb_name=\(snapshot.rimeUserDictionaryName)",
            "rime_runtime_resource_count=\(snapshot.rimeRuntimeResourceCount)",
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

    private func resourceCount(at url: URL) -> Int {
        guard
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return 0
        }

        var count = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                count += 1
            }
        }
        return count
    }

    private func recommendedRepairLevel(
        settingsPathCount: Int,
        defaultSettingsAtStablePath: Bool,
        imePathCount: Int,
        staleLS: Bool,
        hasHitoolbox: Bool,
        imeInstalled: Bool,
        settingsInstalled: Bool
    ) -> Int {
        if staleLS { return 3 }
        if imePathCount > 1 { return 2 }
        if settingsPathCount > 1 && !defaultSettingsAtStablePath { return 2 }
        if hasHitoolbox && !imeInstalled { return 2 }
        if settingsPathCount == 0 || imePathCount == 0 || !imeInstalled || !settingsInstalled {
            return 1
        }
        return 0
    }
}
