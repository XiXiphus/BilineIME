import BilinePreview
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case status
    case translation
    case input
    case appearance
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "状态"
        case .translation: "翻译"
        case .input: "输入"
        case .appearance: "外观"
        case .advanced: "高级"
        }
    }

    var symbolName: String {
        switch self {
        case .status: "checkmark.circle"
        case .translation: "globe"
        case .input: "keyboard"
        case .appearance: "rectangle.on.rectangle"
        case .advanced: "gearshape"
        }
    }
}

struct SettingsRootView: View {
    @StateObject private var model = BilineSettingsModel()
    @State private var selection: SettingsSection? = .status

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .onAppear {
            model.refresh()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .status {
        case .status:
            StatusView(model: model)
        case .translation:
            TranslationSettingsView(model: model)
        case .input:
            InputSettingsView(model: model)
        case .appearance:
            AppearanceSettingsView(model: model)
        case .advanced:
            AdvancedSettingsView(model: model)
        }
    }
}

private struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                    .padding(.bottom, 4)
                content
            }
            .padding(32)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 24)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        Divider()
            .padding(.leading, 20)
    }
}

private struct StatusBadge: View {
    let text: String
    let isPositive: Bool

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .foregroundStyle(isPositive ? .green : .secondary)
    }
}

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
                SettingsRow(title: "设置 App 路径", subtitle: model.settingsAppPath) {
                    StatusBadge(
                        text: model.settingsInstalledAtStablePath ? "稳定路径" : "临时路径",
                        isPositive: model.settingsInstalledAtStablePath)
                }
                SettingsRow(
                    title: "LaunchServices 注册",
                    subtitle: model.settingsRegisteredPaths.joined(separator: "\n")
                ) {
                    StatusBadge(
                        text: model.settingsLaunchServicesPathCount == 1
                            ? "单一路径" : "\(model.settingsLaunchServicesPathCount) 个路径",
                        isPositive: model.settingsLaunchServicesPathCount == 1)
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

struct TranslationSettingsView: View {
    @ObservedObject var model: BilineSettingsModel
    @State private var accessKeyId = ""
    @State private var accessKeySecret = ""

    var body: some View {
        SettingsPage(title: "翻译") {
            SettingsCard {
                SettingsRow(title: "翻译服务", subtitle: "使用你自己的阿里云账号启用英文预览。") {
                    Picker("", selection: $model.provider) {
                        ForEach(TranslationProviderChoice.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                SettingsRow(title: "AccessKey ID", subtitle: model.accessKeyIDStatus) {
                    TextField("AccessKey ID", text: $accessKeyId)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
                SettingsRow(title: "AccessKey Secret", subtitle: model.accessKeySecretStatus) {
                    SecureField("AccessKey Secret", text: $accessKeySecret)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
                SettingsRow(title: "Region") {
                    TextField("cn-hangzhou", text: $model.region)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
                SettingsRow(title: "Endpoint", subtitle: "翻译请求会计入你的阿里云账号用量。") {
                    TextField("https://mt.cn-hangzhou.aliyuncs.com", text: $model.endpoint)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 360)
                }
                HStack(spacing: 12) {
                    Button("保存到本机") {
                        model.saveTranslationSettings(
                            accessKeyId: accessKeyId,
                            accessKeySecret: accessKeySecret
                        )
                        accessKeyId = ""
                        accessKeySecret = ""
                    }
                    Button("测试连接") {
                        model.testAlibabaConnection()
                    }
                    ProgressView()
                        .opacity(model.isTestingConnection ? 1 : 0)
                    Text(
                        model.connectionTestStatus.isEmpty
                            ? model.credentialSaveStatus : model.connectionTestStatus
                    )
                    .foregroundStyle(model.connectionTestSucceeded ? .green : .secondary)
                    Spacer()
                }
                .padding(20)
            }
        }
    }
}

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
                SettingsRow(title: "模糊拼音") {
                    Toggle("", isOn: $model.fuzzyPinyinEnabled)
                        .labelsHidden()
                }
                SettingsRow(title: "已保存字形", subtitle: "defaults: BilineCharacterForm") {
                    StatusBadge(text: model.characterFormDefaultsStatus, isPositive: true)
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
                    Spacer()
                }
                .padding(20)
            }
        }
    }
}

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
