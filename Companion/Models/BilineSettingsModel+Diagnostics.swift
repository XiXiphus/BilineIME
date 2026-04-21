import AppKit
import BilineOperations
import BilineSettings

extension BilineSettingsModel {
    func refresh() {
        let lifecycleSnapshot = DevEnvironmentDiagnostics().snapshot()
        loadDefaults()
        credentialFileStatus = credentialFileStore.status()
        settingsAppPath = Bundle.main.bundleURL.path
        settingsRegisteredPaths = NSWorkspace.shared
            .urlsForApplications(withBundleIdentifier: BilineAppIdentifier.devSettingsBundle)
            .map(\.path)
            .sorted()
        settingsLaunchServicesPathCount = lifecycleSnapshot.settingsLaunchServicesPathCount
        defaultSettingsApplicationPath = lifecycleSnapshot.defaultSettingsApplicationPath ?? ""
        settingsInstalledAtStablePath = lifecycleSnapshot.settingsInstalledAtStablePath
        defaultSettingsAtStablePath = lifecycleSnapshot.defaultSettingsAtStablePath
        imeInstalledAtStablePath = lifecycleSnapshot.imeInstalledAtStablePath
        lifecycleRecommendation = lifecycleSnapshot.recommendedRepairText
        lifecyclePlanText = DevReinstallPlanner().plan(level: .level1).rendered
        characterFormDefaultsRawValue = lifecycleSnapshot.characterFormDefaultsRawValue
        punctuationFormDefaultsRawValue = lifecycleSnapshot.punctuationFormDefaultsRawValue
        imeInstallPath = lifecycleSnapshot.imeInstallPath
        imeInstalled = lifecycleSnapshot.imeInstalled
        imeRunning = lifecycleSnapshot.imeRunning
        rimeUserDictionaryExists = lifecycleSnapshot.rimeUserDictionaryExists
        currentInputSource = lifecycleSnapshot.currentInputSource
    }
}
