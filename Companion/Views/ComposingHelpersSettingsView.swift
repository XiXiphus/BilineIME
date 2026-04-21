import SwiftUI

/// Phase 2 composition convenience toggles. Each row maps 1:1 to a
/// `PostCommitTransform`, so turning a row off completely removes that
/// transform from the IME's pipeline (no dead branches inside the session).
struct ComposingHelpersSettingsView: View {
    @ObservedObject var model: BilineSettingsModel

    var body: some View {
        SettingsPage(title: "输入辅助") {
            SettingsCard {
                SettingsRow(
                    title: "符号自动补全",
                    subtitle: "输入左括号时自动补全配对的右括号"
                ) {
                    Toggle("", isOn: $model.autoPairBrackets).labelsHidden()
                }
                SettingsRow(
                    title: "中文模式下 / 替换为 、",
                    subtitle: "全角标点模式下生效"
                ) {
                    Toggle("", isOn: $model.slashAsChineseEnumeration).labelsHidden()
                }
                SettingsRow(
                    title: "中文与英文/数字间自动加细空格",
                    subtitle: "使用 U+2009 细空格作为排版提示，可一次退格删除"
                ) {
                    Toggle("", isOn: $model.autoSpaceBetweenChineseAndAscii).labelsHidden()
                }
                SettingsRow(
                    title: "数字间冒号自动转半角",
                    subtitle: "在数字之后输入的冒号自动使用半角形式（如 12:00）"
                ) {
                    Toggle("", isOn: $model.normalizeNumericColon).labelsHidden()
                }
            }

            HStack {
                Button("保存") { model.saveComposingHelpers() }
                Button("恢复默认") { model.resetComposingHelpersToDefault() }
                if !model.composingHelpersSaveStatus.isEmpty {
                    Text(model.composingHelpersSaveStatus)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}
