import AppKit
import BilinePreview
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
    static let devInputSourceID = "io.github.xixiphus.inputmethod.BilineIME.dev.pinyin"

    private let defaultsDomain = "io.github.xixiphus.inputmethod.BilineIME.dev"
    private let imeBundleID = "io.github.xixiphus.inputmethod.BilineIME.dev"
    private let keychainStore = KeychainCredentialStore()
    private var credentialFileStore: AlibabaCredentialFileStore {
        AlibabaCredentialFileStore(
            fileURL: AlibabaCredentialFileStore.defaultURL(inputMethodBundleIdentifier: imeBundleID)
        )
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
    @Published var credentialFileStatus = AlibabaCredentialFileStatus(accessKeyIdLength: nil, accessKeySecretLength: nil)
    @Published var keychainStatus = KeychainCredentialStatus(accessKeyIDLength: nil, accessKeySecretLength: nil)
    @Published var credentialSaveStatus = ""
    @Published var connectionTestStatus = ""
    @Published var connectionTestSucceeded = false
    @Published var isTestingConnection = false

    var rimeUserDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(imeBundleID)/Data/Library/Application Support/Rime", isDirectory: true)
    }

    var credentialFileURL: URL {
        credentialFileStore.fileURL
    }

    var accessKeyIDStatus: String {
        if let length = credentialFileStatus.accessKeyIdLength {
            return "已保存，长度 \(length)"
        }
        if let length = keychainStatus.accessKeyIDLength {
            return "Keychain 回退，长度 \(length)"
        }
        return "未保存"
    }

    var accessKeySecretStatus: String {
        if let length = credentialFileStatus.accessKeySecretLength {
            return "已保存，长度 \(length)"
        }
        if let length = keychainStatus.accessKeySecretLength {
            return "Keychain 回退，长度 \(length)"
        }
        return "未保存"
    }

    var translationStatusText: String {
        if provider == .aliyun {
            if credentialFileStatus.isComplete {
                return "已保存到本机输入法容器"
            }
            if keychainStatus.isComplete {
                return "使用 Keychain 兼容回退"
            }
            return "需要保存 AccessKey"
        } else {
            return "英文预览不会调用云翻译"
        }
    }

    func refresh() {
        loadDefaults()
        credentialFileStatus = credentialFileStore.status()
        keychainStatus = keychainStore.status()
        imeInstalled = FileManager.default.fileExists(
            atPath: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Input Methods/BilineIMEDev.app", isDirectory: true)
                .path
        )
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
                    AlibabaCredentialFileRecord(
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

        setDefault(provider.rawValue, forKey: "BilineTranslationProvider")
        setDefault(region.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "BilineAlibabaRegionId")
        setDefault(endpoint.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "BilineAlibabaEndpoint")
        synchronizeDefaults()
        refresh()
    }

    func saveInputSettings() {
        setDefault(fuzzyPinyinEnabled, forKey: "BilineFuzzyPinyinEnabled")
        setDefault(previewEnabled, forKey: "BilinePreviewEnabled")
        setDefault(compactColumnCount, forKey: "BilineCompactColumnCount")
        setDefault(expandedRowCount, forKey: "BilineExpandedRowCount")
        synchronizeDefaults()
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
                guard let credentials = credentialFileStore.load()?.credentials ?? keychainStore.credentials() else {
                    await setConnectionResult("需要保存 AccessKey", success: false)
                    return
                }
                guard let endpointURL = URL(string: endpoint) else {
                    await setConnectionResult("Endpoint 无效", success: false)
                    return
                }
                let provider = AlibabaMachineTranslationProvider(
                    credentials: credentials,
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
        let providerRaw = stringDefault(forKey: "BilineTranslationProvider") ?? TranslationProviderChoice.off.rawValue
        provider = TranslationProviderChoice(rawValue: providerRaw) ?? .off
        region = stringDefault(forKey: "BilineAlibabaRegionId") ?? "cn-hangzhou"
        endpoint = stringDefault(forKey: "BilineAlibabaEndpoint") ?? "https://mt.cn-hangzhou.aliyuncs.com"
        fuzzyPinyinEnabled = boolDefault(forKey: "BilineFuzzyPinyinEnabled") ?? false
        compactColumnCount = resolvedInteger(forKey: "BilineCompactColumnCount", fallback: 5)
        expandedRowCount = resolvedInteger(forKey: "BilineExpandedRowCount", fallback: 5)
        previewEnabled = boolDefault(forKey: "BilinePreviewEnabled") ?? true
    }

    private func resolvedInteger(forKey key: String, fallback: Int) -> Int {
        let value = integerDefault(forKey: key) ?? 0
        return value > 0 ? value : fallback
    }

    private func stringDefault(forKey key: String) -> String? {
        CFPreferencesCopyAppValue(key as CFString, defaultsDomain as CFString) as? String
    }

    private func boolDefault(forKey key: String) -> Bool? {
        CFPreferencesCopyAppValue(key as CFString, defaultsDomain as CFString) as? Bool
    }

    private func integerDefault(forKey key: String) -> Int? {
        if let number = CFPreferencesCopyAppValue(key as CFString, defaultsDomain as CFString) as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func setDefault(_ value: String, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFString, defaultsDomain as CFString)
    }

    private func setDefault(_ value: Bool, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFBoolean, defaultsDomain as CFString)
    }

    private func setDefault(_ value: Int, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, NSNumber(value: value), defaultsDomain as CFString)
    }

    private func synchronizeDefaults() {
        CFPreferencesAppSynchronize(defaultsDomain as CFString)
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
