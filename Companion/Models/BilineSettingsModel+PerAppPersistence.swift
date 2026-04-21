import BilineSettings
import Foundation

extension BilineSettingsModel {
    func savePerAppSettings() {
        defaultsStore.set(offlineMode, forKey: BilineDefaultsKey.offlineMode)
        let cleaned = englishDefaultBundleIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        defaultsStore.set(cleaned, forKey: BilineDefaultsKey.englishDefaultBundleIDs)
        defaultsStore.synchronize()
        perAppSaveStatus = "已保存"
    }

    func resetPerAppSettingsToDefault() {
        offlineMode = false
        englishDefaultBundleIDs = []
        savePerAppSettings()
    }

    func addEnglishDefaultBundleID(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            !englishDefaultBundleIDs.contains(trimmed)
        else { return }
        englishDefaultBundleIDs.append(trimmed)
    }

    func removeEnglishDefaultBundleID(_ id: String) {
        englishDefaultBundleIDs.removeAll(where: { $0 == id })
    }
}
