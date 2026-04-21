import BilineSettings
import SwiftUI

/// Visual settings for the candidate panel: theme mode and font scale.
/// Changes here flow into `LiveSettingsStore`'s `panelThemeMode` and
/// `panelFontScale` snapshot fields, which the running IME picks up via
/// `activateServer`/`commitComposition` refresh.
struct AppearanceSettingsView: View {
    @ObservedObject var model: BilineSettingsModel

    var body: some View {
        SettingsPage(title: "外观") {
            SettingsCard {
                SettingsRow(
                    title: "主题模式",
                    subtitle: "随系统跟随当前外观，浅色/深色强制锁定一种"
                ) {
                    Picker("", selection: $model.panelThemeMode) {
                        Text("跟随系统").tag(PanelThemeMode.system)
                        Text("浅色").tag(PanelThemeMode.light)
                        Text("深色").tag(PanelThemeMode.dark)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                }

                SettingsRow(
                    title: "候选字大小",
                    subtitle: String(
                        format: "倍率 %.2fx，建议范围 0.7x – 1.8x", model.panelFontScale)
                ) {
                    Slider(
                        value: $model.panelFontScale,
                        in: 0.7...1.8,
                        step: 0.05
                    )
                    .frame(width: 220)
                }
            }

            HStack {
                Button("保存外观设置") { model.saveAppearance() }
                Button("恢复默认") { model.resetAppearanceToDefault() }
                if !model.appearanceSaveStatus.isEmpty {
                    Text(model.appearanceSaveStatus)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}
