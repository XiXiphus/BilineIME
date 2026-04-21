import BilineCore
import Foundation

/// Immutable snapshot of every IME setting we expose. The settings store
/// rebuilds this whenever `refresh()` is called, then publishes it to
/// subscribers. Per-keystroke reads are constant-time field accesses on this
/// struct, so live-reloading settings does not put any cost on the hot path.
public struct SettingsSnapshot: Sendable, Equatable {
    public var previewEnabled: Bool
    public var compactColumnCount: Int
    public var expandedRowCount: Int
    public var fuzzyPinyinEnabled: Bool
    public var characterForm: CharacterForm
    public var punctuationForm: PunctuationForm
    public var keyBindings: KeyBindingPolicy
    public var panelThemeMode: PanelThemeMode
    public var panelFontScale: Double
    public var autoPairBrackets: Bool
    public var slashAsChineseEnumeration: Bool
    public var autoSpaceBetweenChineseAndAscii: Bool
    public var normalizeNumericColon: Bool
    public var offlineMode: Bool
    public var englishDefaultBundleIDs: [String]
    public var smartSpellingEnabled: Bool
    public var emojiCandidatesEnabled: Bool

    public init(
        previewEnabled: Bool = true,
        compactColumnCount: Int = 5,
        expandedRowCount: Int = 5,
        fuzzyPinyinEnabled: Bool = false,
        characterForm: CharacterForm = .simplified,
        punctuationForm: PunctuationForm = .fullwidth,
        keyBindings: KeyBindingPolicy = .default,
        panelThemeMode: PanelThemeMode = .system,
        panelFontScale: Double = 1.0,
        autoPairBrackets: Bool = false,
        slashAsChineseEnumeration: Bool = false,
        autoSpaceBetweenChineseAndAscii: Bool = false,
        normalizeNumericColon: Bool = false,
        offlineMode: Bool = false,
        englishDefaultBundleIDs: [String] = [],
        smartSpellingEnabled: Bool = false,
        emojiCandidatesEnabled: Bool = false
    ) {
        self.previewEnabled = previewEnabled
        self.compactColumnCount = compactColumnCount
        self.expandedRowCount = expandedRowCount
        self.fuzzyPinyinEnabled = fuzzyPinyinEnabled
        self.characterForm = characterForm
        self.punctuationForm = punctuationForm
        self.keyBindings = keyBindings
        self.panelThemeMode = panelThemeMode
        self.panelFontScale = panelFontScale
        self.autoPairBrackets = autoPairBrackets
        self.slashAsChineseEnumeration = slashAsChineseEnumeration
        self.autoSpaceBetweenChineseAndAscii = autoSpaceBetweenChineseAndAscii
        self.normalizeNumericColon = normalizeNumericColon
        self.offlineMode = offlineMode
        self.englishDefaultBundleIDs = englishDefaultBundleIDs
        self.smartSpellingEnabled = smartSpellingEnabled
        self.emojiCandidatesEnabled = emojiCandidatesEnabled
    }

    public var pageSize: Int { max(1, compactColumnCount) * max(1, expandedRowCount) }

    /// Loads a fresh snapshot from the supplied defaults domain. Falls back
    /// to safe defaults for any missing/invalid value so the store can never
    /// hand the IME runtime an incoherent configuration.
    public static func load(from defaults: BilineDefaultsStore) -> SettingsSnapshot {
        var snapshot = SettingsSnapshot()
        snapshot.previewEnabled =
            defaults.bool(forKey: BilineDefaultsKey.previewEnabled) ?? snapshot.previewEnabled
        if let value = defaults.integer(forKey: BilineDefaultsKey.compactColumnCount), value > 0 {
            snapshot.compactColumnCount = value
        }
        if let value = defaults.integer(forKey: BilineDefaultsKey.expandedRowCount), value > 0 {
            snapshot.expandedRowCount = value
        }
        snapshot.fuzzyPinyinEnabled =
            defaults.bool(forKey: BilineDefaultsKey.fuzzyPinyinEnabled)
            ?? snapshot.fuzzyPinyinEnabled
        if let raw = defaults.string(forKey: BilineDefaultsKey.characterForm),
            let value = CharacterForm(rawValue: raw)
        {
            snapshot.characterForm = value
        }
        if let raw = defaults.string(forKey: BilineDefaultsKey.punctuationForm),
            let value = PunctuationForm(rawValue: raw)
        {
            snapshot.punctuationForm = value
        }
        snapshot.keyBindings = KeyBindingDefaults.load(from: defaults)
        if let raw = defaults.string(forKey: BilineDefaultsKey.panelThemeMode),
            let value = PanelThemeMode(rawValue: raw)
        {
            snapshot.panelThemeMode = value
        }
        if let value = defaults.double(forKey: BilineDefaultsKey.panelFontScale),
            value > 0
        {
            snapshot.panelFontScale = value
        }
        snapshot.autoPairBrackets =
            defaults.bool(forKey: BilineDefaultsKey.autoPairBrackets)
            ?? snapshot.autoPairBrackets
        snapshot.slashAsChineseEnumeration =
            defaults.bool(forKey: BilineDefaultsKey.slashAsChineseEnumeration)
            ?? snapshot.slashAsChineseEnumeration
        snapshot.autoSpaceBetweenChineseAndAscii =
            defaults.bool(forKey: BilineDefaultsKey.autoSpaceBetweenChineseAndAscii)
            ?? snapshot.autoSpaceBetweenChineseAndAscii
        snapshot.normalizeNumericColon =
            defaults.bool(forKey: BilineDefaultsKey.normalizeNumericColon)
            ?? snapshot.normalizeNumericColon
        snapshot.offlineMode =
            defaults.bool(forKey: BilineDefaultsKey.offlineMode) ?? snapshot.offlineMode
        if let raw = defaults.stringArray(forKey: BilineDefaultsKey.englishDefaultBundleIDs) {
            snapshot.englishDefaultBundleIDs =
                raw
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        snapshot.smartSpellingEnabled =
            defaults.bool(forKey: BilineDefaultsKey.smartSpellingEnabled)
            ?? snapshot.smartSpellingEnabled
        snapshot.emojiCandidatesEnabled =
            defaults.bool(forKey: BilineDefaultsKey.emojiCandidatesEnabled)
            ?? snapshot.emojiCandidatesEnabled
        return snapshot
    }
}
