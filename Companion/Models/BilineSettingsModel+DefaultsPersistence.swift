import BilineCore
import BilineSettings
import Foundation

extension BilineSettingsModel {
    func saveInputSettings() {
        let snapshot = makeSharedConfigurationSnapshot()
        do {
            try communicationHub.saveConfiguration(snapshot)
            inputSaveStatus = "已保存"
        } catch {
            inputSaveStatus = "保存失败"
        }
        refresh()
    }

    func loadDefaults() {
        let snapshot = communicationHub.loadConfiguration()
        provider = TranslationProviderChoice(rawValue: snapshot.translationProvider.rawValue) ?? .off
        region = snapshot.region
        endpoint = snapshot.endpoint
        fuzzyPinyinEnabled = snapshot.settings.fuzzyPinyinEnabled
        characterForm = snapshot.settings.characterForm
        punctuationForm = snapshot.settings.punctuationForm
        compactColumnCount = snapshot.settings.compactColumnCount
        expandedRowCount = snapshot.settings.expandedRowCount
        previewEnabled = snapshot.settings.previewEnabled
        bilingualModeEnabled = snapshot.settings.bilingualModeEnabled
        keyBindings = snapshot.settings.keyBindings
        panelThemeMode = snapshot.settings.panelThemeMode
        panelFontScale = snapshot.settings.panelFontScale
        autoPairBrackets = snapshot.settings.autoPairBrackets
        slashAsChineseEnumeration = snapshot.settings.slashAsChineseEnumeration
        autoSpaceBetweenChineseAndAscii = snapshot.settings.autoSpaceBetweenChineseAndAscii
        normalizeNumericColon = snapshot.settings.normalizeNumericColon
        smartSpellingEnabled = snapshot.settings.smartSpellingEnabled
        emojiCandidatesEnabled = snapshot.settings.emojiCandidatesEnabled
    }

    func saveTranslationDefaults() {
        let snapshot = makeSharedConfigurationSnapshot()
        try? communicationHub.saveConfiguration(snapshot)
    }

    private func makeSharedConfigurationSnapshot() -> BilineSharedConfigurationSnapshot {
        BilineSharedConfigurationSnapshot(
            translationProvider: BilineTranslationProviderChoice(rawValue: provider.rawValue) ?? .off,
            region: region.trimmingCharacters(in: .whitespacesAndNewlines),
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            settings: SettingsSnapshot(
                previewEnabled: previewEnabled,
                bilingualModeEnabled: bilingualModeEnabled,
                compactColumnCount: compactColumnCount,
                expandedRowCount: expandedRowCount,
                fuzzyPinyinEnabled: fuzzyPinyinEnabled,
                characterForm: characterForm,
                punctuationForm: punctuationForm,
                keyBindings: keyBindings,
                panelThemeMode: panelThemeMode,
                panelFontScale: panelFontScale,
                autoPairBrackets: autoPairBrackets,
                slashAsChineseEnumeration: slashAsChineseEnumeration,
                autoSpaceBetweenChineseAndAscii: autoSpaceBetweenChineseAndAscii,
                normalizeNumericColon: normalizeNumericColon,
                smartSpellingEnabled: smartSpellingEnabled,
                emojiCandidatesEnabled: emojiCandidatesEnabled
            )
        )
    }
}
