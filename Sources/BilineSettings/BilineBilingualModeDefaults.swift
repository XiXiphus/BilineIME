import Foundation

public enum BilineBilingualModeDefaults {
    private static let domainsUsingRuntimeSignals = Set([
        BilineAppIdentifier.devInputMethodBundle,
        BilineAppIdentifier.releaseInputMethodBundle,
    ])

    private static let existingInstallDefaultsKeys: [String] = [
        BilineDefaultsKey.translationProvider,
        BilineDefaultsKey.alibabaRegionId,
        BilineDefaultsKey.alibabaEndpoint,
        BilineDefaultsKey.previewEnabled,
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

    public static func resolvedValue(
        from defaults: BilineDefaultsStore,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> Bool {
        if let storedValue = defaults.bool(forKey: BilineDefaultsKey.bilingualModeEnabled) {
            if !defaults.hasValue(forKey: BilineDefaultsKey.didSeedBilingualModeDefault) {
                defaults.set(true, forKey: BilineDefaultsKey.didSeedBilingualModeDefault)
                defaults.synchronize()
            }
            return storedValue
        }

        let resolved = looksLikeExistingInstall(
            defaults: defaults,
            homeDirectory: homeDirectory,
            fileManager: fileManager
        )
        defaults.set(resolved, forKey: BilineDefaultsKey.bilingualModeEnabled)
        defaults.set(true, forKey: BilineDefaultsKey.didSeedBilingualModeDefault)
        defaults.synchronize()
        return resolved
    }

    private static func looksLikeExistingInstall(
        defaults: BilineDefaultsStore,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> Bool {
        if existingInstallDefaultsKeys.contains(where: { defaults.hasValue(forKey: $0) }) {
            return true
        }

        let domainScopedSignals: [URL] = [
            BilineAppPath.preferenceFileURL(domain: defaults.domain, homeDirectory: homeDirectory),
            BilineAppPath.credentialFileURL(
                inputMethodBundleIdentifier: defaults.domain,
                homeDirectory: homeDirectory
            ),
            BilineAppPath.rimeUserDirectory(
                inputMethodBundleIdentifier: defaults.domain,
                homeDirectory: homeDirectory
            ),
        ]

        if domainScopedSignals.contains(where: { fileManager.fileExists(atPath: $0.path) }) {
            return true
        }

        guard domainsUsingRuntimeSignals.contains(defaults.domain) else {
            return false
        }

        let runtimeSignals: [URL] = [
            BilineAppPath.inputMethodRuntimeCredentialFileURL(homeDirectory: homeDirectory),
            BilineAppPath.applicationSupportDirectory(homeDirectory: homeDirectory)
                .appendingPathComponent("Rime/user", isDirectory: true),
            BilineAppPath.inputMethodRuntimeRimeUserDictionaryURL(
                characterForm: "simplified",
                homeDirectory: homeDirectory
            ),
            BilineAppPath.inputMethodRuntimeRimeUserDictionaryURL(
                characterForm: "traditional",
                homeDirectory: homeDirectory
            ),
        ]

        return runtimeSignals.contains(where: { fileManager.fileExists(atPath: $0.path) })
    }
}
