import Foundation

public struct BilineAlibabaCredentialRecord: Codable, Equatable, Sendable {
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
}

public enum BilineCredentialFileLoadError: Error, Equatable, Sendable {
    case missing
    case unreadable
    case decodingFailed
}

public struct BilineCredentialFileStatus: Equatable, Sendable {
    public let fileURL: URL
    public let accessKeyIdLength: Int?
    public let accessKeySecretLength: Int?
    public let loadError: BilineCredentialFileLoadError?

    public init(
        fileURL: URL,
        accessKeyIdLength: Int?,
        accessKeySecretLength: Int?,
        loadError: BilineCredentialFileLoadError?
    ) {
        self.fileURL = fileURL
        self.accessKeyIdLength = accessKeyIdLength
        self.accessKeySecretLength = accessKeySecretLength
        self.loadError = loadError
    }

    public var isComplete: Bool {
        accessKeyIdLength != nil && accessKeySecretLength != nil && loadError == nil
    }
}

public struct BilineCredentialFileStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init(inputMethodBundleIdentifier: String) {
        self.fileURL = BilineAppPath.credentialFileURL(
            inputMethodBundleIdentifier: inputMethodBundleIdentifier
        )
    }

    public func load() throws -> BilineAlibabaCredentialRecord {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw BilineCredentialFileLoadError.missing
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw BilineCredentialFileLoadError.unreadable
        }
        do {
            return try JSONDecoder().decode(BilineAlibabaCredentialRecord.self, from: data)
        } catch {
            throw BilineCredentialFileLoadError.decodingFailed
        }
    }

    public func loadIfAvailable() -> BilineAlibabaCredentialRecord? {
        try? load()
    }

    public func status() -> BilineCredentialFileStatus {
        do {
            let record = try load()
            return BilineCredentialFileStatus(
                fileURL: fileURL,
                accessKeyIdLength: record.accessKeyId.isEmpty ? nil : record.accessKeyId.count,
                accessKeySecretLength: record.accessKeySecret.isEmpty ? nil : record.accessKeySecret.count,
                loadError: nil
            )
        } catch let error as BilineCredentialFileLoadError {
            return BilineCredentialFileStatus(
                fileURL: fileURL,
                accessKeyIdLength: nil,
                accessKeySecretLength: nil,
                loadError: error
            )
        } catch {
            return BilineCredentialFileStatus(
                fileURL: fileURL,
                accessKeyIdLength: nil,
                accessKeySecretLength: nil,
                loadError: .unreadable
            )
        }
    }

    public func save(_ record: BilineAlibabaCredentialRecord) throws {
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
