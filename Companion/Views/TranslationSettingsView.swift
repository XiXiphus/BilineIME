import SwiftUI

struct TranslationSettingsView: View {
    @ObservedObject var model: BilineSettingsModel
    @State private var accessKeyId = ""
    @State private var accessKeySecret = ""

    var body: some View {
        SettingsPage(title: "翻译配置") {
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
