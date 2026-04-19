import BilinePreview
import Foundation

struct DefaultSettingsStore: SettingsStore {
    let targetLanguage: TargetLanguage
    let previewEnabled: Bool
    let compactColumnCount: Int
    let expandedRowCount: Int
    let fuzzyPinyinEnabled: Bool
    let characterForm: CharacterForm

    var pageSize: Int {
        compactColumnCount * expandedRowCount
    }

    init(
        targetLanguage: TargetLanguage = .english,
        previewEnabled: Bool = true,
        compactColumnCount: Int = 5,
        expandedRowCount: Int = 5,
        fuzzyPinyinEnabled: Bool = UserDefaults.standard.bool(forKey: "BilineFuzzyPinyinEnabled"),
        characterForm: CharacterForm = CharacterForm(
            rawValue: UserDefaults.standard.string(forKey: "BilineCharacterForm") ?? ""
        ) ?? .simplified
    ) {
        self.targetLanguage = targetLanguage
        self.previewEnabled = previewEnabled
        self.compactColumnCount = max(1, compactColumnCount)
        self.expandedRowCount = max(1, expandedRowCount)
        self.fuzzyPinyinEnabled = fuzzyPinyinEnabled
        self.characterForm = characterForm
    }
}
