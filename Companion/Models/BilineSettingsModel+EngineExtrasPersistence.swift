import BilineSettings
import Foundation

/// Persistence helpers for Phase 4 engine-side toggles. The toggles are
/// stored now so the Settings UI lands ahead of the engine work; flipping
/// them today is a no-op until the Rime schema (smart spelling) and emoji
/// candidate source land in their own milestones.
extension BilineSettingsModel {
    func saveEngineExtras() {
        defaultsStore.set(smartSpellingEnabled, forKey: BilineDefaultsKey.smartSpellingEnabled)
        defaultsStore.set(emojiCandidatesEnabled, forKey: BilineDefaultsKey.emojiCandidatesEnabled)
        defaultsStore.synchronize()
        engineExtrasSaveStatus = "已保存"
    }

    func resetEngineExtrasToDefault() {
        smartSpellingEnabled = false
        emojiCandidatesEnabled = false
        saveEngineExtras()
    }
}
