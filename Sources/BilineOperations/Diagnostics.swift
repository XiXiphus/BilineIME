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
        let resolvedSettingsURL = resolvedInstalledURL(
            registeredURLs: settingsURLs,
            directCandidates: paths.devSettingsInstallURLs(for: .all),
            preferredURL: paths.devSettingsInstallURL
        )
        let resolvedInputMethodURL = resolvedInstalledURL(
            registeredURLs: imeURLs,
            directCandidates: paths.devInputMethodInstallURLs(for: .all),
            preferredURL: paths.devInputMethodInstallURL
        )
        let resolvedBrokerURL = resolvedDirectInstalledURL(
            candidates: paths.devBrokerInstallURLs(for: .all),
            preferredURL: paths.devBrokerInstallURL
        )
        let resolvedBrokerLaunchAgentURL = resolvedDirectInstalledURL(
            candidates: paths.devBrokerLaunchAgentURLs(for: .all),
            preferredURL: BilineAppPath.devBrokerLaunchAgentURL(
                surface: .user,
                homeDirectory: paths.homeDirectory
            )
        )
        let hitoolbox = readHitoolboxState()
        let credentialStatus = BilineCredentialVault(
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
        let staleLS = (settingsURLs + imeURLs).contains {
            !fileManager.fileExists(atPath: $0.path)
        }
        let hasHitoolbox = hitoolbox.contains("io.github.xixiphus.inputmethod.BilineIME")
        let sharedDefaults = BilineDefaultsStore.shared(for: BilineAppIdentifier.devInputMethodBundle)
        let characterFormRaw =
            sharedDefaults.string(forKey: BilineDefaultsKey.characterForm) ?? ""
        let punctuationFormRaw =
            sharedDefaults.string(forKey: BilineDefaultsKey.punctuationForm) ?? ""
        let resolvedCharacterForm = characterFormRaw.isEmpty ? "simplified" : characterFormRaw
        let schemaID = BilineAppPath.rimeSchemaID(characterForm: resolvedCharacterForm)
        let userDictionaryName = BilineAppPath.rimeUserDictionaryName(
            characterForm: resolvedCharacterForm)
        let activeRimeUserDB = BilineAppPath.rimeUserDictionaryURL(
            inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
            characterForm: resolvedCharacterForm
        )
        let runtimeResourceURL = (resolvedInputMethodURL ?? paths.devInputMethodInstallURL)
            .appendingPathComponent("Contents/Resources/RimeRuntime/rime-data", isDirectory: true)
        let imeInstalled = resolvedInputMethodURL != nil
        let settingsInstalled = resolvedSettingsURL != nil
        let brokerInstalled = resolvedBrokerURL != nil
        let brokerLaunchAgentInstalled = resolvedBrokerLaunchAgentURL != nil
        let readiness = BilineInputSourceReadinessChecker().evaluate(
            bundleInstalled: imeInstalled
        )
        let recommendation = recommendedAction(
            resolvedSettingsURL: resolvedSettingsURL,
            resolvedInputMethodURL: resolvedInputMethodURL,
            settingsPathCount: settingsPathCount,
            defaultSettingsAtStablePath: defaultSettingsURL?.path.hasSuffix(
                "/Applications/BilineSettingsDev.app") == true,
            imePathCount: imePathCount,
            staleLS: staleLS,
            hasHitoolbox: hasHitoolbox,
            imeInstalled: imeInstalled,
            settingsInstalled: settingsInstalled,
            brokerInstalled: brokerInstalled,
            brokerLaunchAgentInstalled: brokerLaunchAgentInstalled
        )

        return DevEnvironmentSnapshot(
            imeInstallPath: resolvedInputMethodURL?.path ?? paths.devInputMethodInstallURL.path,
            imeInstalled: imeInstalled,
            imeRunning: isProcessRunning(BilineAppProcessName.devInputMethod),
            settingsInstallPath: resolvedSettingsURL?.path ?? paths.devSettingsInstallURL.path,
            settingsInstalled: settingsInstalled,
            settingsRunning: isProcessRunning(BilineAppProcessName.devSettings),
            brokerInstallPath: resolvedBrokerURL?.path ?? paths.devBrokerInstallURL.path,
            brokerInstalled: brokerInstalled,
            brokerRunning: isProcessRunning(BilineAppProcessName.devBroker),
            brokerLaunchAgentPath: resolvedBrokerLaunchAgentURL?.path
                ?? BilineAppPath.devBrokerLaunchAgentURL(
                    surface: .user,
                    homeDirectory: paths.homeDirectory
                ).path,
            brokerLaunchAgentInstalled: brokerLaunchAgentInstalled,
            settingsLaunchServicesPathCount: settingsPathCount,
            defaultSettingsApplicationPath: defaultSettingsURL?.path,
            imeLaunchServicesPathCount: imePathCount,
            hasStaleLaunchServicesEntry: staleLS,
            hasBilineHitoolboxState: hasHitoolbox,
            currentInputSource: currentSource,
            credentialFilePath: credentialLocation(credentialStatus.fileURL),
            credentialFileComplete: credentialStatus.isComplete,
            rimeUserDictionaryPath: activeRimeUserDB.path,
            rimeUserDictionaryExists: fileManager.fileExists(atPath: activeRimeUserDB.path),
            characterFormDefaultsRawValue: characterFormRaw,
            punctuationFormDefaultsRawValue: punctuationFormRaw,
            rimeSchemaID: schemaID,
            rimeUserDictionaryName: userDictionaryName,
            rimeRuntimeResourceCount: resourceCount(at: runtimeResourceURL),
            recommendedAction: recommendation.spec,
            recommendedActionReason: recommendation.reason,
            inputSourceReadiness: readiness
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
            "broker_install=\(snapshot.brokerInstallPath)",
            "broker_installed=\(snapshot.brokerInstalled)",
            "broker_running=\(snapshot.brokerRunning)",
            "broker_launch_agent=\(snapshot.brokerLaunchAgentPath)",
            "broker_launch_agent_installed=\(snapshot.brokerLaunchAgentInstalled)",
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
            "recommended_action=\(snapshot.recommendedAction?.actionText ?? "none")",
            "recommended_reason=\(snapshot.recommendedActionReason.isEmpty ? "none" : snapshot.recommendedActionReason)",
            "input_source_id=\(snapshot.inputSourceReadiness.inputSourceID)",
            "input_source_state=\(snapshot.inputSourceReadiness.state.shortDescription)",
            "input_source_ready=\(snapshot.inputSourceReadiness.isReady)",
            "input_source_summary=\(snapshot.inputSourceReadiness.summary)",
            "input_source_remediation=\(snapshot.inputSourceReadiness.remediation.isEmpty ? "none" : snapshot.inputSourceReadiness.remediation.joined(separator: " | "))",
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

    private func credentialLocation(_ url: URL) -> String {
        url.isFileURL ? url.path : url.absoluteString
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

    private func resolvedInstalledURL(
        registeredURLs: [URL],
        directCandidates: [URL],
        preferredURL: URL
    ) -> URL? {
        let existingURLs = uniqueURLs((registeredURLs + directCandidates).filter {
            fileManager.fileExists(atPath: $0.path)
        })
        for candidate in directCandidates where existingURLs.contains(candidate) {
            return candidate
        }
        if let firstRegistered = existingURLs.first {
            return firstRegistered
        }
        return fileManager.fileExists(atPath: preferredURL.path) ? preferredURL : nil
    }

    private func resolvedDirectInstalledURL(
        candidates: [URL],
        preferredURL: URL
    ) -> URL? {
        let existingURLs = uniqueURLs(candidates.filter {
            fileManager.fileExists(atPath: $0.path)
        })
        if let first = existingURLs.first {
            return first
        }
        return fileManager.fileExists(atPath: preferredURL.path) ? preferredURL : nil
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls {
            if seen.insert(url.path).inserted {
                result.append(url)
            }
        }
        return result
    }

    private func recommendedAction(
        resolvedSettingsURL: URL?,
        resolvedInputMethodURL: URL?,
        settingsPathCount: Int,
        defaultSettingsAtStablePath: Bool,
        imePathCount: Int,
        staleLS: Bool,
        hasHitoolbox: Bool,
        imeInstalled: Bool,
        settingsInstalled: Bool,
        brokerInstalled: Bool,
        brokerLaunchAgentInstalled: Bool
    ) -> (spec: LifecycleOperationSpec?, reason: String) {
        if staleLS {
            return (.reset(scope: .all, depth: .launchServicesReset), "LaunchServices still references stale Biline paths.")
        }
        if imePathCount > 1 {
            return (.reset(scope: .all, depth: .cachePrune), "Multiple Biline IME LaunchServices paths were found.")
        }
        if settingsPathCount > 1 && !defaultSettingsAtStablePath {
            return (.reset(scope: .all, depth: .cachePrune), "Settings App default LaunchServices path is not stable.")
        }
        if hasHitoolbox && !imeInstalled {
            return (.reset(scope: .all, depth: .cachePrune), "HIToolbox still references Biline after the app bundle disappeared.")
        }
        if !brokerInstalled || !brokerLaunchAgentInstalled {
            return (.install(scope: preferredInstallScope(
                resolvedSettingsURL: resolvedSettingsURL,
                resolvedInputMethodURL: resolvedInputMethodURL
            )), "Broker executable or LaunchAgent is missing.")
        }
        if !imeInstalled || !settingsInstalled {
            return (.install(scope: preferredInstallScope(
                resolvedSettingsURL: resolvedSettingsURL,
                resolvedInputMethodURL: resolvedInputMethodURL
            )), "One or more Biline dev app bundles are missing.")
        }
        return (nil, "")
    }

    private func preferredInstallScope(
        resolvedSettingsURL: URL?,
        resolvedInputMethodURL: URL?
    ) -> LifecycleScope {
        if resolvedInputMethodURL?.path.hasPrefix("/Library/") == true
            || resolvedSettingsURL?.path.hasPrefix("/Applications/") == true
        {
            return .system
        }
        return .user
    }
}
