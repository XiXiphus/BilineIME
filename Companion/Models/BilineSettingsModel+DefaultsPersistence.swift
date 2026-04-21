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
        inputSaveStatus = "已保存"
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
        keyBindings = KeyBindingDefaults.load(from: defaultsStore)
        if let raw = defaultsStore.string(forKey: BilineDefaultsKey.panelThemeMode),
            let mode = PanelThemeMode(rawValue: raw)
        {
            panelThemeMode = mode
        } else {
            panelThemeMode = .system
        }
        if let scale = defaultsStore.double(forKey: BilineDefaultsKey.panelFontScale), scale > 0 {
            panelFontScale = scale
        } else {
            panelFontScale = 1.0
        }
        autoPairBrackets =
            defaultsStore.bool(forKey: BilineDefaultsKey.autoPairBrackets) ?? false
        slashAsChineseEnumeration =
            defaultsStore.bool(forKey: BilineDefaultsKey.slashAsChineseEnumeration) ?? false
        autoSpaceBetweenChineseAndAscii =
            defaultsStore.bool(forKey: BilineDefaultsKey.autoSpaceBetweenChineseAndAscii) ?? false
        normalizeNumericColon =
            defaultsStore.bool(forKey: BilineDefaultsKey.normalizeNumericColon) ?? false
        offlineMode = defaultsStore.bool(forKey: BilineDefaultsKey.offlineMode) ?? false
        englishDefaultBundleIDs =
            defaultsStore.stringArray(forKey: BilineDefaultsKey.englishDefaultBundleIDs)
            .map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
            ?? []
        smartSpellingEnabled =
            defaultsStore.bool(forKey: BilineDefaultsKey.smartSpellingEnabled) ?? false
        emojiCandidatesEnabled =
            defaultsStore.bool(forKey: BilineDefaultsKey.emojiCandidatesEnabled) ?? false
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
