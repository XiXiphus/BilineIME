import BilineCore
import Foundation

public struct BilineSharedConfigurationSnapshot: Codable, Equatable, Sendable {
    public var translationProvider: BilineTranslationProviderChoice
    public var region: String
    public var endpoint: String
    public var settings: SettingsSnapshot

    public init(
        translationProvider: BilineTranslationProviderChoice = .off,
        region: String = "cn-hangzhou",
        endpoint: String = "https://mt.cn-hangzhou.aliyuncs.com",
        settings: SettingsSnapshot = SettingsSnapshot()
    ) {
        self.translationProvider = translationProvider
        self.region = region
        self.endpoint = endpoint
        self.settings = settings
    }
}

public struct BilineSharedConfigurationStore: Sendable {
    public let inputMethodBundleIdentifier: String
    public let defaultsStore: BilineDefaultsStore

    public init(
        inputMethodBundleIdentifier: String = BilineAppIdentifier.devInputMethodBundle,
        defaultsStore: BilineDefaultsStore? = nil
    ) {
        self.inputMethodBundleIdentifier = inputMethodBundleIdentifier
        self.defaultsStore =
            defaultsStore
            ?? BilineDefaultsStore.shared(for: inputMethodBundleIdentifier)
    }

    public func load() -> BilineSharedConfigurationSnapshot {
        defaultsStore.synchronize()
        let settings = SettingsSnapshot.load(from: defaultsStore)
        let provider =
            defaultsStore.string(forKey: BilineDefaultsKey.translationProvider)
            .flatMap(BilineTranslationProviderChoice.init(rawValue:))
            ?? .off
        let region = defaultsStore.string(forKey: BilineDefaultsKey.alibabaRegionId) ?? "cn-hangzhou"
        let endpoint =
            defaultsStore.string(forKey: BilineDefaultsKey.alibabaEndpoint)
            ?? "https://mt.cn-hangzhou.aliyuncs.com"
        return BilineSharedConfigurationSnapshot(
            translationProvider: provider,
            region: region,
            endpoint: endpoint,
            settings: settings
        )
    }

    public func save(_ snapshot: BilineSharedConfigurationSnapshot) {
        defaultsStore.set(snapshot.translationProvider.rawValue, forKey: BilineDefaultsKey.translationProvider)
        defaultsStore.set(snapshot.region, forKey: BilineDefaultsKey.alibabaRegionId)
        defaultsStore.set(snapshot.endpoint, forKey: BilineDefaultsKey.alibabaEndpoint)
        defaultsStore.set(snapshot.settings.previewEnabled, forKey: BilineDefaultsKey.previewEnabled)
        defaultsStore.set(snapshot.settings.bilingualModeEnabled, forKey: BilineDefaultsKey.bilingualModeEnabled)
        defaultsStore.set(true, forKey: BilineDefaultsKey.didSeedBilingualModeDefault)
        defaultsStore.set(snapshot.settings.compactColumnCount, forKey: BilineDefaultsKey.compactColumnCount)
        defaultsStore.set(snapshot.settings.expandedRowCount, forKey: BilineDefaultsKey.expandedRowCount)
        defaultsStore.set(snapshot.settings.fuzzyPinyinEnabled, forKey: BilineDefaultsKey.fuzzyPinyinEnabled)
        defaultsStore.set(snapshot.settings.characterForm.rawValue, forKey: BilineDefaultsKey.characterForm)
        defaultsStore.set(snapshot.settings.punctuationForm.rawValue, forKey: BilineDefaultsKey.punctuationForm)
        defaultsStore.set(snapshot.settings.keyBindings.encodeOrEmpty(), forKey: BilineDefaultsKey.keyBindingPolicy)
        defaultsStore.set(snapshot.settings.panelThemeMode.rawValue, forKey: BilineDefaultsKey.panelThemeMode)
        defaultsStore.set(snapshot.settings.panelFontScale, forKey: BilineDefaultsKey.panelFontScale)
        defaultsStore.set(snapshot.settings.autoPairBrackets, forKey: BilineDefaultsKey.autoPairBrackets)
        defaultsStore.set(snapshot.settings.slashAsChineseEnumeration, forKey: BilineDefaultsKey.slashAsChineseEnumeration)
        defaultsStore.set(snapshot.settings.autoSpaceBetweenChineseAndAscii, forKey: BilineDefaultsKey.autoSpaceBetweenChineseAndAscii)
        defaultsStore.set(snapshot.settings.normalizeNumericColon, forKey: BilineDefaultsKey.normalizeNumericColon)
        defaultsStore.set(snapshot.settings.smartSpellingEnabled, forKey: BilineDefaultsKey.smartSpellingEnabled)
        defaultsStore.set(snapshot.settings.emojiCandidatesEnabled, forKey: BilineDefaultsKey.emojiCandidatesEnabled)
        defaultsStore.synchronize()
    }

    public func resetToDefaults() {
        let keys = [
            BilineDefaultsKey.translationProvider,
            BilineDefaultsKey.alibabaRegionId,
            BilineDefaultsKey.alibabaEndpoint,
            BilineDefaultsKey.previewEnabled,
            BilineDefaultsKey.bilingualModeEnabled,
            BilineDefaultsKey.compactColumnCount,
            BilineDefaultsKey.expandedRowCount,
            BilineDefaultsKey.fuzzyPinyinEnabled,
            BilineDefaultsKey.characterForm,
            BilineDefaultsKey.punctuationForm,
            BilineDefaultsKey.keyBindingPolicy,
            BilineDefaultsKey.panelThemeMode,
            BilineDefaultsKey.panelFontScale,
            BilineDefaultsKey.autoPairBrackets,
            BilineDefaultsKey.slashAsChineseEnumeration,
            BilineDefaultsKey.autoSpaceBetweenChineseAndAscii,
            BilineDefaultsKey.normalizeNumericColon,
            BilineDefaultsKey.smartSpellingEnabled,
            BilineDefaultsKey.emojiCandidatesEnabled,
        ]
        for key in keys {
            defaultsStore.removeValue(forKey: key)
        }
        defaultsStore.removeValue(forKey: BilineDefaultsKey.didSeedBilingualModeDefault)
        defaultsStore.synchronize()
    }
}

private extension KeyBindingPolicy {
    func encodeOrEmpty() -> Data {
        (try? encode()) ?? Data()
    }
}
