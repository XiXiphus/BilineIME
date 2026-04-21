import BilineSettings
import Foundation

public struct AlibabaCredentialOperations {
    public static let defaultRegionId = "cn-hangzhou"
    public static let defaultEndpoint = "https://mt.cn-hangzhou.aliyuncs.com"

    public let domain: String
    public let store: BilineCredentialFileStore
    public let defaultsStore: BilineDefaultsStore
    public let runner: any CommandRunning
    private let fileManager: FileManager

    public init(
        domain: String = BilineAppIdentifier.devInputMethodBundle,
        fileURL: URL? = nil,
        runner: any CommandRunning = ProcessCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.domain = domain
        self.store = BilineCredentialFileStore(
            fileURL: fileURL
                ?? BilineAppPath.credentialFileURL(
                    inputMethodBundleIdentifier: domain))
        self.defaultsStore = BilineDefaultsStore(domain: domain)
        self.runner = runner
        self.fileManager = fileManager
    }

    public func statusReport() -> String {
        let provider = defaultsStore.string(forKey: BilineDefaultsKey.translationProvider)
        let region = defaultsStore.string(forKey: BilineDefaultsKey.alibabaRegionId)
        let endpoint = defaultsStore.string(forKey: BilineDefaultsKey.alibabaEndpoint)
        let status = store.status()

        var lines = [
            "domain=\(domain)",
            "provider=\(provider ?? "<missing>")",
            "region=\(region ?? "<missing>")",
            "endpoint=\(endpoint ?? "<missing>")",
        ]

        switch status.loadError {
        case nil:
            lines.append("credential_file=\(status.fileURL.path)")
            lines.append(
                "credential_file_accessKeyId=\(status.accessKeyIdLength.map(String.init) ?? "missing")"
            )
            lines.append(
                "credential_file_accessKeySecret=\(status.accessKeySecretLength.map(String.init) ?? "missing")"
            )
        case .missing:
            lines.append("credential_file=missing")
        case .unreadable, .decodingFailed:
            lines.append("credential_file=unreadable")
        }

        return lines.joined(separator: "\n")
    }

    public func configure(record: BilineAlibabaCredentialRecord) throws -> String {
        guard !record.accessKeyId.isEmpty, !record.accessKeySecret.isEmpty else {
            throw BilineOperationError.unsupportedArguments(
                "AccessKey ID and secret are required.")
        }

        try store.save(record)
        defaultsStore.set("aliyun", forKey: BilineDefaultsKey.translationProvider)
        defaultsStore.set(record.regionId, forKey: BilineDefaultsKey.alibabaRegionId)
        defaultsStore.set(record.endpoint, forKey: BilineDefaultsKey.alibabaEndpoint)
        defaultsStore.synchronize()
        refreshDefaults()

        return [
            "Alibaba translation provider configured for \(domain).",
            statusReport(),
        ].joined(separator: "\n")
    }

    public func clear() -> String {
        try? fileManager.removeItem(at: store.fileURL)
        defaultsStore.removeValue(forKey: BilineDefaultsKey.translationProvider)
        defaultsStore.removeValue(forKey: BilineDefaultsKey.alibabaRegionId)
        defaultsStore.removeValue(forKey: BilineDefaultsKey.alibabaEndpoint)
        defaultsStore.synchronize()
        refreshDefaults()
        return "Alibaba translation provider credentials cleared for \(domain)."
    }

    private func refreshDefaults() {
        _ = try? runner.run("/usr/bin/killall", ["cfprefsd"], allowFailure: true)
    }
}
