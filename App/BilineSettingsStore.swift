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
        previewEnabled: Bool = Self.boolDefault(forKey: "BilinePreviewEnabled") ?? true,
        compactColumnCount: Int = Self.integerDefault(forKey: "BilineCompactColumnCount") ?? 5,
        expandedRowCount: Int = Self.integerDefault(forKey: "BilineExpandedRowCount") ?? 5,
        fuzzyPinyinEnabled: Bool = Self.boolDefault(forKey: "BilineFuzzyPinyinEnabled") ?? false,
        characterForm: CharacterForm = .simplified
    ) {
        self.targetLanguage = targetLanguage
        self.previewEnabled = previewEnabled
        self.compactColumnCount = max(1, compactColumnCount)
        self.expandedRowCount = max(1, expandedRowCount)
        self.fuzzyPinyinEnabled = fuzzyPinyinEnabled
        self.characterForm = .simplified
    }

    private static func boolDefault(forKey key: String) -> Bool? {
        UserDefaults.standard.object(forKey: key) as? Bool
    }

    private static func integerDefault(forKey key: String) -> Int? {
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : nil
    }
}
