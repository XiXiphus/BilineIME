import BilineSettings
import Foundation

extension BilineSettingsModel {
    func saveAppearance() {
        defaultsStore.set(panelThemeMode.rawValue, forKey: BilineDefaultsKey.panelThemeMode)
        defaultsStore.set(panelFontScale, forKey: BilineDefaultsKey.panelFontScale)
        defaultsStore.synchronize()
        appearanceSaveStatus = "已保存"
    }

    func resetAppearanceToDefault() {
        panelThemeMode = .system
        panelFontScale = 1.0
        saveAppearance()
    }
}
