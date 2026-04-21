import BilineCore
import SwiftUI

/// Engine-side input settings: character form, punctuation form, fuzzy
/// pinyin, and candidate matrix dimensions. These map directly onto
/// settings the Rime engine and `BilingualInputSession` consume.
struct InputEngineSettingsView: View {
    @ObservedObject var model: BilineSettingsModel

    var body: some View {
        SettingsPage(title: "输入引擎") {
            SettingsCard {
                SettingsRow(title: "字形输出") {
                    Picker("", selection: $model.characterForm) {
                        Text("简体").tag(CharacterForm.simplified)
                        Text("繁体").tag(CharacterForm.traditional)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)
                }
                SettingsRow(title: "标点输出") {
                    Picker("", selection: $model.punctuationForm) {
                        Text("全角").tag(PunctuationForm.fullwidth)
                        Text("半角").tag(PunctuationForm.halfwidth)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)
                }
                SettingsRow(title: "模糊拼音") {
                    Toggle("", isOn: $model.fuzzyPinyinEnabled)
                        .labelsHidden()
                }
                SettingsRow(title: "候选列数") {
                    Stepper(value: $model.compactColumnCount, in: 1...5) {
                        Text("\(model.compactColumnCount)")
                            .frame(width: 28, alignment: .trailing)
                    }
                }
                SettingsRow(title: "展开行数") {
                    Stepper(value: $model.expandedRowCount, in: 1...5) {
                        Text("\(model.expandedRowCount)")
                            .frame(width: 28, alignment: .trailing)
                    }
                }
                HStack {
                    Button("保存输入设置") { model.saveInputSettings() }
                    if !model.inputSaveStatus.isEmpty {
                        Text(model.inputSaveStatus)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(20)
            }

            SettingsCard {
                Text("引擎扩展（开发中）")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                SettingsRow(
                    title: "智能拼写纠错",
                    subtitle: "切换 Rime spelling_corrector，需要后续 schema 切换才会真正生效"
                ) {
                    Toggle("", isOn: $model.smartSpellingEnabled).labelsHidden()
                }
                SettingsRow(
                    title: "表情候选词",
                    subtitle: "在候选词中混入常用表情/颜文字，候选源对接为后续里程碑"
                ) {
                    Toggle("", isOn: $model.emojiCandidatesEnabled).labelsHidden()
                }

                HStack {
                    Button("保存") { model.saveEngineExtras() }
                    Button("恢复默认") { model.resetEngineExtrasToDefault() }
                    if !model.engineExtrasSaveStatus.isEmpty {
                        Text(model.engineExtrasSaveStatus)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(20)
            }
        }
    }
}
