import Foundation

public struct AlibabaCredentialFileRecord: Codable, Equatable, Sendable {
    public let accessKeyId: String
    public let accessKeySecret: String
    public let regionId: String
    public let endpoint: String

    public init(
        accessKeyId: String,
        accessKeySecret: String,
        regionId: String,
        endpoint: String
    ) {
        self.accessKeyId = accessKeyId
        self.accessKeySecret = accessKeySecret
        self.regionId = regionId
        self.endpoint = endpoint
    }

    public var credentials: AlibabaMachineTranslationCredentials {
        AlibabaMachineTranslationCredentials(
            accessKeyId: accessKeyId,
            accessKeySecret: accessKeySecret
        )
    }
}

public struct AlibabaCredentialFileStatus: Equatable, Sendable {
    public let accessKeyIdLength: Int?
    public let accessKeySecretLength: Int?

    public init(accessKeyIdLength: Int?, accessKeySecretLength: Int?) {
        self.accessKeyIdLength = accessKeyIdLength
        self.accessKeySecretLength = accessKeySecretLength
    }

    public var isComplete: Bool {
        accessKeyIdLength != nil && accessKeySecretLength != nil
    }
}

public struct AlibabaCredentialFileStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultURL(inputMethodBundleIdentifier: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Containers/\(inputMethodBundleIdentifier)/Data/Library/Application Support/BilineIME",
                isDirectory: true
            )
            .appendingPathComponent("alibaba-credentials.json", isDirectory: false)
    }

    public func load() -> AlibabaCredentialFileRecord? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(AlibabaCredentialFileRecord.self, from: data)
    }

    public func status() -> AlibabaCredentialFileStatus {
        guard let record = load() else {
            return AlibabaCredentialFileStatus(accessKeyIdLength: nil, accessKeySecretLength: nil)
        }
        return AlibabaCredentialFileStatus(
            accessKeyIdLength: record.accessKeyId.count,
            accessKeySecretLength: record.accessKeySecret.count
        )
    }

    public func save(_ record: AlibabaCredentialFileRecord) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o700)],
            ofItemAtPath: directory.path
        )

        let data = try JSONEncoder().encode(record)
        try data.write(to: fileURL, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: fileURL.path
        )
    }
}
