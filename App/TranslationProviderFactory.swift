import BilineIPC
import BilineSettings
import BilinePreview
import Foundation
import OSLog

enum TranslationProviderFactory {
    fileprivate static var communicationHub: BilineCommunicationHub {
        BilineCommunicationHub(
            inputMethodBundleIdentifier: Bundle.main.bundleIdentifier ?? BilineAppIdentifier.devInputMethodBundle
        )
    }

    static func configuredProvider() -> (any TranslationProvider)? {
        guard selectedProvider == "aliyun" else { return nil }
        return FileBackedAlibabaTranslationProvider()
    }

    static var selectedProvider: String? {
        communicationHub.loadConfiguration().translationProvider.rawValue
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

    fileprivate static func makeAlibabaProvider() -> AlibabaMachineTranslationProvider? {
        let localRecord = AlibabaCredentialResolver.localCredentialRecord()
        guard let localRecord else {
            return nil
        }

        let configuration = communicationHub.loadConfiguration()
        let regionId = normalized(configuration.region)
            ?? normalized(localRecord.regionId)
            ?? "cn-hangzhou"
        let endpointString = normalized(configuration.endpoint)
            ?? normalized(localRecord.endpoint)
        let endpoint = endpointString
            .flatMap(URL.init(string:))
            ?? URL(string: "https://mt.cn-hangzhou.aliyuncs.com")!

        return AlibabaMachineTranslationProvider(
            credentials: AlibabaMachineTranslationCredentials(
                accessKeyId: localRecord.accessKeyId,
                accessKeySecret: localRecord.accessKeySecret
            ),
            configuration: AlibabaMachineTranslationConfiguration(
                endpoint: endpoint,
                regionId: regionId
            )
        )
    }

    fileprivate static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

}

struct FileBackedAlibabaTranslationProvider: BatchTranslationProvider {
    let providerIdentifier = "aliyun.machine-translation"
    let providerModelIdentifier = "GetBatchTranslate"
    let translationProfileIdentifier = "file-backed"
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.github.xixiphus.inputmethod.BilineIME",
        category: "translation-provider"
    )

    func translate(_ text: String, target: TargetLanguage) async throws -> String {
        let result = try await translateBatch([text], target: target)
        guard let translated = result[text] else {
            throw UnavailableTranslationProviderError.notConfigured
        }
        return translated
    }

    func translateBatch(_ texts: [String], target: TargetLanguage) async throws -> [String: String] {
        guard let provider = TranslationProviderFactory.makeAlibabaProvider() else {
            logger.error("Alibaba provider unavailable: credential file could not be loaded for bundle=\(Bundle.main.bundleIdentifier ?? "<missing>", privacy: .public) path=\(BilineAppPath.inputMethodRuntimeCredentialFileURL().path, privacy: .public)")
            throw UnavailableTranslationProviderError.notConfigured
        }
        do {
            let result = try await provider.translateBatch(texts, target: target)
            logger.debug("Alibaba provider translated batch textCount=\(texts.count, privacy: .public) resultCount=\(result.count, privacy: .public)")
            return result
        } catch {
            logger.error("Alibaba provider failed batch textCount=\(texts.count, privacy: .public) error=\(String(describing: error), privacy: .public)")
            throw error
        }
    }
}

enum AlibabaCredentialResolver {
    static func localCredentialRecord() -> BilineAlibabaCredentialRecord? {
        try? TranslationProviderFactory.communicationHub.loadCredentialRecord()
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
