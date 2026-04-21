import BilineCore
import BilineSettings
import Combine
import Foundation

@MainActor
final class BilineSettingsModel: ObservableObject {
    static let devInputSourceID = BilineAppIdentifier.devInputSource

    let defaultsDomain = BilineAppIdentifier.devInputMethodBundle
    let imeBundleID = BilineAppIdentifier.devInputMethodBundle
    var defaultsStore: BilineDefaultsStore {
        BilineDefaultsStore(domain: defaultsDomain)
    }
    var credentialFileStore: BilineCredentialFileStore {
        BilineCredentialFileStore(inputMethodBundleIdentifier: imeBundleID)
    }

    @Published var provider: TranslationProviderChoice = .off
    @Published var region = "cn-hangzhou"
    @Published var endpoint = "https://mt.cn-hangzhou.aliyuncs.com"
    @Published var compactColumnCount = 5
    @Published var expandedRowCount = 5
    @Published var fuzzyPinyinEnabled = false
    @Published var characterForm: CharacterForm = .simplified
    @Published var punctuationForm: PunctuationForm = .fullwidth
    @Published var previewEnabled = true
    @Published var imeInstalled = false
    @Published var imeRunning = false
    @Published var rimeUserDictionaryExists = false
    @Published var currentInputSource = ""
    @Published var settingsAppPath = ""
    @Published var settingsRegisteredPaths: [String] = []
    @Published var settingsLaunchServicesPathCount = 0
    @Published var defaultSettingsApplicationPath = ""
    @Published var settingsInstalledAtStablePath = false
    @Published var defaultSettingsAtStablePath = false
    @Published var imeInstalledAtStablePath = false
    @Published var lifecycleRecommendation = "未知"
    @Published var lifecyclePlanText = ""
    @Published var characterFormDefaultsRawValue = ""
    @Published var punctuationFormDefaultsRawValue = ""
    @Published var imeInstallPath = BilineAppPath.devInputMethodInstallURL.path
    @Published var credentialFileStatus = BilineCredentialFileStatus(
        fileURL: BilineAppPath.credentialFileURL(
            inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle),
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

    var rimeUserDictionaryURL: URL {
        BilineAppPath.rimeUserDictionaryURL(
            inputMethodBundleIdentifier: imeBundleID,
            characterForm: characterForm.rawValue
        )
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

    var characterFormTitle: String {
        switch characterForm {
        case .simplified:
            return "简体"
        case .traditional:
            return "繁体"
        }
    }

    var characterFormDefaultsStatus: String {
        characterFormDefaultsRawValue.isEmpty ? "未保存，默认简体" : characterFormDefaultsRawValue
    }

    var punctuationFormTitle: String {
        switch punctuationForm {
        case .fullwidth:
            return "全角"
        case .halfwidth:
            return "半角"
        }
    }

    var punctuationFormDefaultsStatus: String {
        punctuationFormDefaultsRawValue.isEmpty ? "未保存，默认全角" : punctuationFormDefaultsRawValue
    }
}
