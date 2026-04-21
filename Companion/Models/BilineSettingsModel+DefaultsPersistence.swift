import BilineCore
import BilineSettings
import Foundation

extension BilineSettingsModel {
    func saveInputSettings() {
        defaultsStore.set(fuzzyPinyinEnabled, forKey: BilineDefaultsKey.fuzzyPinyinEnabled)
        defaultsStore.set(previewEnabled, forKey: BilineDefaultsKey.previewEnabled)
        defaultsStore.set(compactColumnCount, forKey: BilineDefaultsKey.compactColumnCount)
        defaultsStore.set(expandedRowCount, forKey: BilineDefaultsKey.expandedRowCount)
        defaultsStore.set(characterForm.rawValue, forKey: BilineDefaultsKey.characterForm)
        defaultsStore.set(punctuationForm.rawValue, forKey: BilineDefaultsKey.punctuationForm)
        defaultsStore.synchronize()
        refresh()
    }

    func loadDefaults() {
        let providerRaw =
            defaultsStore.string(forKey: BilineDefaultsKey.translationProvider)
            ?? TranslationProviderChoice.off.rawValue
        provider = TranslationProviderChoice(rawValue: providerRaw) ?? .off
        region = defaultsStore.string(forKey: BilineDefaultsKey.alibabaRegionId) ?? "cn-hangzhou"
        endpoint =
            defaultsStore.string(forKey: BilineDefaultsKey.alibabaEndpoint)
            ?? "https://mt.cn-hangzhou.aliyuncs.com"
        fuzzyPinyinEnabled =
            defaultsStore.bool(forKey: BilineDefaultsKey.fuzzyPinyinEnabled) ?? false
        characterForm =
            CharacterForm(
                rawValue: defaultsStore.string(forKey: BilineDefaultsKey.characterForm) ?? "")
            ?? .simplified
        punctuationForm =
            PunctuationForm(
                rawValue: defaultsStore.string(forKey: BilineDefaultsKey.punctuationForm) ?? "")
            ?? .fullwidth
        compactColumnCount = resolvedInteger(
            forKey: BilineDefaultsKey.compactColumnCount, fallback: 5)
        expandedRowCount = resolvedInteger(forKey: BilineDefaultsKey.expandedRowCount, fallback: 5)
        previewEnabled = defaultsStore.bool(forKey: BilineDefaultsKey.previewEnabled) ?? true
    }

    func saveTranslationDefaults() {
        defaultsStore.set(provider.rawValue, forKey: BilineDefaultsKey.translationProvider)
        defaultsStore.set(
            region.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: BilineDefaultsKey.alibabaRegionId)
        defaultsStore.set(
            endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: BilineDefaultsKey.alibabaEndpoint)
        defaultsStore.synchronize()
    }

    private func resolvedInteger(forKey key: String, fallback: Int) -> Int {
        let value = defaultsStore.integer(forKey: key) ?? 0
        return value > 0 ? value : fallback
    }
}
