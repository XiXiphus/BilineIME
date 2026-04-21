import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var model: BilineSettingsModel

    var body: some View {
        SettingsPage(title: "高级") {
            SettingsCard {
                SettingsRow(title: "阿里云凭据文件", subtitle: model.credentialFileURL.path) {
                    StatusBadge(
                        text: model.credentialFileStatus.isComplete ? "已保存" : "未保存",
                        isPositive: model.credentialFileStatus.isComplete)
                }
                SettingsRow(title: "Rime 用户目录", subtitle: model.rimeUserDirectory.path) {
                    Button("打开") { model.openRimeUserDirectory() }
                }
                SettingsRow(title: "Rime 用户词典", subtitle: model.rimeUserDictionaryURL.path) {
                    StatusBadge(
                        text: model.rimeUserDictionaryExists ? "存在" : "未生成",
                        isPositive: model.rimeUserDictionaryExists)
                }
                SettingsRow(title: "Level 1 重装计划", subtitle: model.lifecyclePlanText) {
                    StatusBadge(text: "手动宿主", isPositive: true)
                }
                SettingsRow(title: "诊断") {
                    Button("刷新状态") { model.refresh() }
                }
            }
        }
    }
}
