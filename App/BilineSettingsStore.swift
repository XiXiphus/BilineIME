import BilinePreview
import Foundation

struct DefaultSettingsStore: SettingsStore {
    let targetLanguage: TargetLanguage
    let previewEnabled: Bool
    let pageSize: Int

    init(
        targetLanguage: TargetLanguage = .english,
        previewEnabled: Bool = true,
        pageSize: Int = 5
    ) {
        self.targetLanguage = targetLanguage
        self.previewEnabled = previewEnabled
        self.pageSize = pageSize
    }
}
