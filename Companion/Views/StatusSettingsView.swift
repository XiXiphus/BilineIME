import SwiftUI

struct StatusView: View {
    @ObservedObject var model: BilineSettingsModel

    var body: some View {
        SettingsPage(title: "状态") {
            SettingsCard {
                SettingsRow(title: "输入法安装") {
                    StatusBadge(
                        text: model.imeInstalled ? "已安装" : "未安装", isPositive: model.imeInstalled)
                }
                SettingsRow(title: "输入法路径", subtitle: model.imeInstallPath) {
                    StatusBadge(
                        text: model.imeInstalled ? "存在" : "缺失", isPositive: model.imeInstalled)
                }
                SettingsRow(title: "当前输入源", subtitle: model.currentInputSource) {
                    StatusBadge(
                        text: model.currentInputSource == BilineSettingsModel.devInputSourceID
                            ? "BilineIME Dev" : "未选择",
                        isPositive: model.currentInputSource == BilineSettingsModel.devInputSourceID
                    )
                }
                SettingsRow(title: "输入法进程") {
                    StatusBadge(
                        text: model.imeRunning ? "运行中" : "未运行", isPositive: model.imeRunning)
                }
                SettingsRow(title: "字形输出") {
                    StatusBadge(text: model.characterFormTitle, isPositive: true)
                }
                SettingsRow(title: "标点输出") {
                    StatusBadge(text: model.punctuationFormTitle, isPositive: true)
                }
                SettingsRow(title: "设置 App 路径", subtitle: model.settingsAppPath) {
                    StatusBadge(
                        text: model.settingsInstalledAtStablePath ? "稳定路径" : "临时路径",
                        isPositive: model.settingsInstalledAtStablePath)
                }
                SettingsRow(
                    title: "LaunchServices 默认设置 App",
                    subtitle: model.defaultSettingsApplicationPath.isEmpty
                        ? "未找到默认应用"
                        : model.defaultSettingsApplicationPath
                ) {
                    StatusBadge(
                        text: model.defaultSettingsAtStablePath ? "稳定默认路径" : "默认路径异常",
                        isPositive: model.defaultSettingsAtStablePath)
                }
                SettingsRow(
                    title: "LaunchServices 注册噪音",
                    subtitle: model.settingsRegisteredPaths.joined(separator: "\n")
                ) {
                    StatusBadge(
                        text: model.settingsLaunchServicesPathCount <= 1
                            ? "无重复注册" : "\(model.settingsLaunchServicesPathCount) 个路径",
                        isPositive: model.settingsLaunchServicesPathCount <= 1)
                }
                SettingsRow(title: "生命周期建议") {
                    StatusBadge(
                        text: model.lifecycleRecommendation,
                        isPositive: model.lifecycleRecommendation == "无需修复")
                }
                SettingsRow(title: "翻译服务", subtitle: model.translationStatusText) {
                    StatusBadge(
                        text: model.provider == .aliyun ? "阿里云" : "关闭",
                        isPositive: model.provider == .aliyun)
                }
                HStack {
                    Button("刷新状态") { model.refresh() }
                    Button("打开输入源设置") { model.openInputSourceSettings() }
                    Spacer()
                }
                .padding(20)
            }
        }
    }
}
