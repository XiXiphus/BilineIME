import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var model: BilineSettingsModel

    var body: some View {
        SettingsPage(title: "外观") {
            SettingsCard {
                SettingsRow(title: "英文预览") {
                    Toggle("", isOn: $model.previewEnabled)
                        .labelsHidden()
                }
                HStack {
                    Button("保存外观设置") { model.saveInputSettings() }
                    Spacer()
                }
                .padding(20)
            }
        }
    }
}
