import BilinePreview
import Foundation

struct DefaultSettingsStore: SettingsStore {
    let targetLanguage: TargetLanguage
    let annotationEnabled: Bool
    let pageSize: Int

    init(
        targetLanguage: TargetLanguage = .english,
        annotationEnabled: Bool = true,
        pageSize: Int = 5
    ) {
        self.targetLanguage = targetLanguage
        self.annotationEnabled = annotationEnabled
        self.pageSize = pageSize
    }
}
