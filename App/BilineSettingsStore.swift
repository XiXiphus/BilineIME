import BilineCore
import BilinePreview
import BilineSettings
import Foundation

struct DefaultSettingsStore: SettingsStore {
    let targetLanguage: TargetLanguage
    let previewEnabled: Bool
    let compactColumnCount: Int
    let expandedRowCount: Int
    let fuzzyPinyinEnabled: Bool
    let characterForm: CharacterForm
    let punctuationForm: PunctuationForm

    var pageSize: Int {
        compactColumnCount * expandedRowCount
    }

    init(
        targetLanguage: TargetLanguage = .english,
        previewEnabled: Bool = Self.boolDefault(forKey: BilineDefaultsKey.previewEnabled) ?? true,
        compactColumnCount: Int = Self.integerDefault(forKey: BilineDefaultsKey.compactColumnCount)
            ?? 5,
        expandedRowCount: Int = Self.integerDefault(forKey: BilineDefaultsKey.expandedRowCount)
            ?? 5,
        fuzzyPinyinEnabled: Bool = Self.boolDefault(forKey: BilineDefaultsKey.fuzzyPinyinEnabled)
            ?? false,
        characterForm: CharacterForm = Self.characterFormDefault() ?? .simplified,
        punctuationForm: PunctuationForm = Self.punctuationFormDefault() ?? .fullwidth
    ) {
        self.targetLanguage = targetLanguage
        self.previewEnabled = previewEnabled
        self.compactColumnCount = max(1, compactColumnCount)
        self.expandedRowCount = max(1, expandedRowCount)
        self.fuzzyPinyinEnabled = fuzzyPinyinEnabled
        self.characterForm = characterForm
        self.punctuationForm = punctuationForm
    }

    private static func boolDefault(forKey key: String) -> Bool? {
        UserDefaults.standard.object(forKey: key) as? Bool
    }

    private static func integerDefault(forKey key: String) -> Int? {
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : nil
    }

    private static func characterFormDefault() -> CharacterForm? {
        guard let rawValue = UserDefaults.standard.string(forKey: BilineDefaultsKey.characterForm)
        else {
            return nil
        }
        return CharacterForm(rawValue: rawValue)
    }

    private static func punctuationFormDefault() -> PunctuationForm? {
        guard let rawValue = UserDefaults.standard.string(forKey: BilineDefaultsKey.punctuationForm)
        else {
            return nil
        }
        return PunctuationForm(rawValue: rawValue)
    }
}
