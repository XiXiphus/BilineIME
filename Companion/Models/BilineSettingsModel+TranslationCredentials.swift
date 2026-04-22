import BilinePreview
import BilineSettings
import Foundation

extension BilineSettingsModel {
    func saveTranslationSettings(accessKeyId: String, accessKeySecret: String) {
        connectionTestStatus = ""
        connectionTestSucceeded = false
        let trimmedAccessKeyId = accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccessKeySecret = accessKeySecret.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedAccessKeyId.isEmpty && !trimmedAccessKeySecret.isEmpty {
            do {
                try communicationHub.saveCredentialRecord(
                    BilineAlibabaCredentialRecord(
                        accessKeyId: trimmedAccessKeyId,
                        accessKeySecret: trimmedAccessKeySecret,
                        regionId: region.trimmingCharacters(in: .whitespacesAndNewlines),
                        endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
                credentialSaveStatus = "已保存"
            } catch {
                credentialSaveStatus = "保存失败"
            }
        } else if trimmedAccessKeyId.isEmpty != trimmedAccessKeySecret.isEmpty {
            credentialSaveStatus = "AccessKey ID 和 Secret 需要同时填写"
        } else {
            credentialSaveStatus = "已保存设置"
        }

        saveTranslationDefaults()
        refresh()
    }

    func testAlibabaConnection() {
        guard !isTestingConnection else { return }
        isTestingConnection = true
        connectionTestStatus = "测试中"
        connectionTestSucceeded = false

        Task {
            defer { Task { @MainActor in self.isTestingConnection = false } }
            do {
                let record = try communicationHub.loadCredentialRecord()
                guard let endpointURL = URL(string: endpoint) else {
                    await setConnectionResult("Endpoint 无效", success: false)
                    return
                }
                let provider = AlibabaMachineTranslationProvider(
                    credentials: AlibabaMachineTranslationCredentials(
                        accessKeyId: record.accessKeyId,
                        accessKeySecret: record.accessKeySecret
                    ),
                    configuration: AlibabaMachineTranslationConfiguration(
                        endpoint: endpointURL,
                        regionId: region
                    )
                )
                let result = try await provider.translateBatch(["你好", "好苹果"], target: .english)
                let passed = !(result["你好"] ?? "").isEmpty && !(result["好苹果"] ?? "").isEmpty
                await setConnectionResult(passed ? "测试通过" : "没有返回翻译", success: passed)
            } catch AlibabaMachineTranslationError.authenticationFailed(let code, _) {
                await setConnectionResult("鉴权失败：\(code)", success: false)
            } catch AlibabaMachineTranslationError.throttled(let code, _) {
                await setConnectionResult("请求受限：\(code)", success: false)
            } catch BilineCredentialFileLoadError.missing {
                await setConnectionResult("需要保存 AccessKey", success: false)
            } catch BilineCredentialFileLoadError.unreadable,
                BilineCredentialFileLoadError.decodingFailed
            {
                await setConnectionResult("凭据文件不可读", success: false)
            } catch let error as URLError {
                await setConnectionResult("网络失败：\(error.code.rawValue)", success: false)
            } catch {
                await setConnectionResult("请求失败", success: false)
            }
        }
    }

    private func setConnectionResult(_ message: String, success: Bool) async {
        await MainActor.run {
            connectionTestStatus = message
            connectionTestSucceeded = success
        }
    }
}
