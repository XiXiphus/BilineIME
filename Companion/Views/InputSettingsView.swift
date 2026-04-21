import BilineCore
import SwiftUI

struct InputSettingsView: View {
    @ObservedObject var model: BilineSettingsModel

    var body: some View {
        SettingsPage(title: "输入") {
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
        }
    }
}
