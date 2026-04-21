import BilineSettings
import Foundation

extension BilineSettingsModel {
    func saveComposingHelpers() {
        defaultsStore.set(autoPairBrackets, forKey: BilineDefaultsKey.autoPairBrackets)
        defaultsStore.set(
            slashAsChineseEnumeration, forKey: BilineDefaultsKey.slashAsChineseEnumeration)
        defaultsStore.set(
            autoSpaceBetweenChineseAndAscii,
            forKey: BilineDefaultsKey.autoSpaceBetweenChineseAndAscii)
        defaultsStore.set(normalizeNumericColon, forKey: BilineDefaultsKey.normalizeNumericColon)
        defaultsStore.synchronize()
        composingHelpersSaveStatus = "已保存"
    }

    func resetComposingHelpersToDefault() {
        autoPairBrackets = false
        slashAsChineseEnumeration = false
        autoSpaceBetweenChineseAndAscii = false
        normalizeNumericColon = false
        saveComposingHelpers()
    }
}
