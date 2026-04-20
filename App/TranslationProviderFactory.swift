import BilinePreview
import Foundation
import Security

enum TranslationProviderFactory {
    private enum DefaultsKey {
        static let provider = "BilineTranslationProvider"
        static let accessKeyId = "BilineAlibabaAccessKeyId"
        static let accessKeySecret = "BilineAlibabaAccessKeySecret"
        static let regionId = "BilineAlibabaRegionId"
        static let endpoint = "BilineAlibabaEndpoint"
    }

    static func configuredProvider() -> (any TranslationProvider)? {
        guard selectedProvider == "aliyun" else { return nil }
        return makeAlibabaProvider()
    }

    static var selectedProvider: String? {
        UserDefaults.standard.string(forKey: DefaultsKey.provider)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static var aliyunSchedulerConfiguration: TranslationPreviewScheduler.Configuration {
        TranslationPreviewScheduler.Configuration(
            maxConcurrentRequests: 4,
            maxRequestsPerSecond: 45,
            requestTimeout: .milliseconds(1_200),
            rateLimitBackoff: .seconds(2),
            batchWindow: .milliseconds(50),
            maxBatchSize: 50
        )
    }

    private static func makeAlibabaProvider() -> (any TranslationProvider)? {
        guard let credentials = AlibabaCredentialResolver.credentials() else {
            return nil
        }

        let defaults = UserDefaults.standard
        let regionId = normalized(defaults.string(forKey: DefaultsKey.regionId)) ?? "cn-hangzhou"
        let endpoint = normalized(defaults.string(forKey: DefaultsKey.endpoint))
            .flatMap(URL.init(string:))
            ?? URL(string: "https://mt.cn-hangzhou.aliyuncs.com")!

        return AlibabaMachineTranslationProvider(
            credentials: credentials,
            configuration: AlibabaMachineTranslationConfiguration(
                endpoint: endpoint,
                regionId: regionId
            )
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum AlibabaCredentialResolver {
    private enum Keychain {
        static let service = "BilineIME.AlibabaMachineTranslation"
        static let accessKeyIdAccount = "accessKeyId"
        static let accessKeySecretAccount = "accessKeySecret"
    }

    private enum DefaultsKey {
        static let accessKeyId = "BilineAlibabaAccessKeyId"
        static let accessKeySecret = "BilineAlibabaAccessKeySecret"
    }

    static func credentials() -> AlibabaMachineTranslationCredentials? {
        let accessKeyId = keychainPassword(account: Keychain.accessKeyIdAccount)
            ?? defaultsString(forKey: DefaultsKey.accessKeyId)
        let accessKeySecret = keychainPassword(account: Keychain.accessKeySecretAccount)
            ?? defaultsString(forKey: DefaultsKey.accessKeySecret)

        guard let accessKeyId, let accessKeySecret else {
            return nil
        }

        return AlibabaMachineTranslationCredentials(
            accessKeyId: accessKeyId,
            accessKeySecret: accessKeySecret
        )
    }

    private static func defaultsString(forKey key: String) -> String? {
        let value = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func keychainPassword(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keychain.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct UnavailableTranslationProvider: TranslationProvider {
    let providerIdentifier = "unavailable"

    func translate(_ text: String, target: TargetLanguage) async throws -> String {
        throw UnavailableTranslationProviderError.notConfigured
    }
}

enum UnavailableTranslationProviderError: Error {
    case notConfigured
}
