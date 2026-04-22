import BilineCore
import SwiftUI

struct InputSettingsView: View {
    @ObservedObject var model: BilineSettingsModel

    var body: some View {
        SettingsPage(title: "输入设置") {
            SettingsSectionHeading(title: "输入引擎")
            InputEngineSettingsContent(model: model)

            SettingsSectionHeading(title: "按键")
            KeyBindingSettingsContent(
                model: model,
                pageTurnDefaultDash: [
                    KeyChord(character: "-", keyCode: 27),
                    KeyChord(character: "=", keyCode: 24),
                ],
                pageTurnDefaultBracket: [
                    KeyChord(character: "[", keyCode: 33),
                    KeyChord(character: "]", keyCode: 30),
                ],
                candidate2Semicolon: KeyChord(character: ";", keyCode: 41),
                candidate3Apostrophe: KeyChord(character: "'", keyCode: 39)
            )

            SettingsSectionHeading(title: "输入辅助")
            ComposingHelpersSettingsContent(model: model)
        }
    }
}
