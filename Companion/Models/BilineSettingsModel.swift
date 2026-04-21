import AppKit
import BilinePreview
import BilineSettings
import Carbon
import Combine
import Foundation

enum TranslationProviderChoice: String, CaseIterable, Identifiable {
    case off
    case aliyun

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "关闭"
        case .aliyun: "阿里云机器翻译"
        }
    }
}

@MainActor
final class BilineSettingsModel: ObservableObject {
    static let devInputSourceID = BilineAppIdentifier.devInputSource

    private let defaultsDomain = BilineAppIdentifier.devInputMethodBundle
    private let imeBundleID = BilineAppIdentifier.devInputMethodBundle
    private var defaultsStore: BilineDefaultsStore {
        BilineDefaultsStore(domain: defaultsDomain)
    }
    private var credentialFileStore: BilineCredentialFileStore {
        BilineCredentialFileStore(inputMethodBundleIdentifier: imeBundleID)
    }

    @Published var provider: TranslationProviderChoice = .off
    @Published var region = "cn-hangzhou"
    @Published var endpoint = "https://mt.cn-hangzhou.aliyuncs.com"
    @Published var compactColumnCount = 5
    @Published var expandedRowCount = 5
    @Published var fuzzyPinyinEnabled = false
    @Published var previewEnabled = true
    @Published var imeInstalled = false
    @Published var imeRunning = false
    @Published var currentInputSource = ""
    @Published var settingsAppPath = ""
    @Published var settingsRegisteredPaths: [String] = []
    @Published var imeInstallPath = BilineAppPath.devInputMethodInstallURL.path
    @Published var credentialFileStatus = BilineCredentialFileStatus(
        fileURL: BilineAppPath.credentialFileURL(inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle),
        accessKeyIdLength: nil,
        accessKeySecretLength: nil,
        loadError: .missing
    )
    @Published var credentialSaveStatus = ""
    @Published var connectionTestStatus = ""
    @Published var connectionTestSucceeded = false
    @Published var isTestingConnection = false

    var rimeUserDirectory: URL {
        BilineAppPath.rimeUserDirectory(inputMethodBundleIdentifier: imeBundleID)
    }

    var credentialFileURL: URL {
        credentialFileStore.fileURL
    }

    var accessKeyIDStatus: String {
        if let length = credentialFileStatus.accessKeyIdLength {
            return "已保存，长度 \(length)"
        }
        return "未保存"
    }

    var accessKeySecretStatus: String {
        if let length = credentialFileStatus.accessKeySecretLength {
            return "已保存，长度 \(length)"
        }
        return "未保存"
    }

    var translationStatusText: String {
        if provider == .aliyun {
            if credentialFileStatus.isComplete {
                return "已保存到本机输入法容器"
            }
            if let error = credentialFileStatus.loadError, error != .missing {
                return "凭据文件不可读"
            }
            return "需要保存 AccessKey"
        } else {
            return "英文预览不会调用云翻译"
        }
    }

    func refresh() {
        loadDefaults()
        credentialFileStatus = credentialFileStore.status()
        settingsAppPath = Bundle.main.bundleURL.path
        settingsRegisteredPaths = NSWorkspace.shared
            .urlsForApplications(withBundleIdentifier: BilineAppIdentifier.devSettingsBundle)
            .map(\.path)
            .sorted()
        imeInstallPath = BilineAppPath.devInputMethodInstallURL.path
        imeInstalled = FileManager.default.fileExists(atPath: imeInstallPath)
        imeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: imeBundleID).isEmpty
        currentInputSource = currentKeyboardInputSourceID()
    }

    func saveTranslationSettings(accessKeyId: String, accessKeySecret: String) {
        connectionTestStatus = ""
        connectionTestSucceeded = false
        let trimmedAccessKeyId = accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccessKeySecret = accessKeySecret.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedAccessKeyId.isEmpty && !trimmedAccessKeySecret.isEmpty {
            do {
                try credentialFileStore.save(
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

        defaultsStore.set(provider.rawValue, forKey: BilineDefaultsKey.translationProvider)
        defaultsStore.set(region.trimmingCharacters(in: .whitespacesAndNewlines), forKey: BilineDefaultsKey.alibabaRegionId)
        defaultsStore.set(endpoint.trimmingCharacters(in: .whitespacesAndNewlines), forKey: BilineDefaultsKey.alibabaEndpoint)
        defaultsStore.synchronize()
        refresh()
    }

    func saveInputSettings() {
        defaultsStore.set(fuzzyPinyinEnabled, forKey: BilineDefaultsKey.fuzzyPinyinEnabled)
        defaultsStore.set(previewEnabled, forKey: BilineDefaultsKey.previewEnabled)
        defaultsStore.set(compactColumnCount, forKey: BilineDefaultsKey.compactColumnCount)
        defaultsStore.set(expandedRowCount, forKey: BilineDefaultsKey.expandedRowCount)
        defaultsStore.synchronize()
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
                let record = try credentialFileStore.load()
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

    func openInputSourceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    func openRimeUserDirectory() {
        try? FileManager.default.createDirectory(at: rimeUserDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(rimeUserDirectory)
    }

    private func loadDefaults() {
        let providerRaw = defaultsStore.string(forKey: BilineDefaultsKey.translationProvider) ?? TranslationProviderChoice.off.rawValue
        provider = TranslationProviderChoice(rawValue: providerRaw) ?? .off
        region = defaultsStore.string(forKey: BilineDefaultsKey.alibabaRegionId) ?? "cn-hangzhou"
        endpoint = defaultsStore.string(forKey: BilineDefaultsKey.alibabaEndpoint) ?? "https://mt.cn-hangzhou.aliyuncs.com"
        fuzzyPinyinEnabled = defaultsStore.bool(forKey: BilineDefaultsKey.fuzzyPinyinEnabled) ?? false
        compactColumnCount = resolvedInteger(forKey: BilineDefaultsKey.compactColumnCount, fallback: 5)
        expandedRowCount = resolvedInteger(forKey: BilineDefaultsKey.expandedRowCount, fallback: 5)
        previewEnabled = defaultsStore.bool(forKey: BilineDefaultsKey.previewEnabled) ?? true
    }

    private func resolvedInteger(forKey key: String, fallback: Int) -> Int {
        let value = defaultsStore.integer(forKey: key) ?? 0
        return value > 0 ? value : fallback
    }

    private func setConnectionResult(_ message: String, success: Bool) async {
        await MainActor.run {
            connectionTestStatus = message
            connectionTestSucceeded = success
        }
    }

    private func currentKeyboardInputSourceID() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
        else {
            return ""
        }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? String ?? ""
    }
}
