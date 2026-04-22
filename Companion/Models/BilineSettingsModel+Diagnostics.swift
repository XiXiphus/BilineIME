import AppKit
import BilineOperations
import BilineSettings

extension BilineSettingsModel {
    func refresh() {
        let lifecycleSnapshot = communicationHub.diagnosticsSnapshot()
        loadDefaults()
        credentialFileStatus = communicationHub.credentialStatus()
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
        brokerInstallPath = lifecycleSnapshot.brokerInstallPath
        brokerInstalled = lifecycleSnapshot.brokerInstalled
        brokerRunning = lifecycleSnapshot.brokerRunning
        brokerLaunchAgentPath = lifecycleSnapshot.brokerLaunchAgentPath
        brokerLaunchAgentInstalled = lifecycleSnapshot.brokerLaunchAgentInstalled
        lifecycleRecommendation = lifecycleSnapshot.recommendedActionText
        lifecycleRecommendationReason = lifecycleSnapshot.recommendedActionReason
        if let action = lifecycleSnapshot.recommendedAction {
            lifecyclePlanText = LifecycleOperationPlanner().plan(action).rendered
        } else {
            lifecyclePlanText = ""
        }
        characterFormDefaultsRawValue = lifecycleSnapshot.characterFormDefaultsRawValue
        punctuationFormDefaultsRawValue = lifecycleSnapshot.punctuationFormDefaultsRawValue
        imeInstallPath = lifecycleSnapshot.imeInstallPath
        imeInstalled = lifecycleSnapshot.imeInstalled
        imeRunning = lifecycleSnapshot.imeRunning
        rimeUserDictionaryExists = lifecycleSnapshot.rimeUserDictionaryExists
        currentInputSource = lifecycleSnapshot.currentInputSource
    }
}
