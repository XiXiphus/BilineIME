import Foundation
import Security

public struct BilineKeychainCredentialStore: Sendable {
    public let service: String
    public let account: String

    public init(
        inputMethodBundleIdentifier: String = BilineAppIdentifier.devInputMethodBundle,
        service: String? = nil,
        account: String? = nil
    ) {
        self.service =
            service
            ?? BilineSharedIdentifier.keychainService(for: inputMethodBundleIdentifier)
        self.account = account ?? inputMethodBundleIdentifier
    }

    public func load() throws -> BilineAlibabaCredentialRecord {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            throw BilineCredentialFileLoadError.missing
        }
        guard status == errSecSuccess, let data = result as? Data else {
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

    public func save(_ record: BilineAlibabaCredentialRecord) throws {
        let data = try JSONEncoder().encode(record)
        let updateStatus = SecItemUpdate(
            baseQuery() as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insertQuery = baseQuery()
            insertQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw BilineCredentialFileLoadError.unreadable
            }
        default:
            throw BilineCredentialFileLoadError.unreadable
        }
    }

    public func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    public func status() -> BilineCredentialFileStatus {
        do {
            let record = try load()
            return BilineCredentialFileStatus(
                fileURL: URL(string: "keychain://\(service)/\(account)")!,
                accessKeyIdLength: record.accessKeyId.isEmpty ? nil : record.accessKeyId.count,
                accessKeySecretLength: record.accessKeySecret.isEmpty ? nil : record.accessKeySecret.count,
                loadError: nil
            )
        } catch let error as BilineCredentialFileLoadError {
            return BilineCredentialFileStatus(
                fileURL: URL(string: "keychain://\(service)/\(account)")!,
                accessKeyIdLength: nil,
                accessKeySecretLength: nil,
                loadError: error
            )
        } catch {
            return BilineCredentialFileStatus(
                fileURL: URL(string: "keychain://\(service)/\(account)")!,
                accessKeyIdLength: nil,
                accessKeySecretLength: nil,
                loadError: .unreadable
            )
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
    }
}

public struct BilineCredentialVault: Sendable {
    public let keychainStore: BilineKeychainCredentialStore
    public let legacyFileStore: BilineCredentialFileStore
    private let preferLegacyOnly: Bool

    public var fileURL: URL {
        legacyFileStore.fileURL
    }

    public init(
        inputMethodBundleIdentifier: String = BilineAppIdentifier.devInputMethodBundle,
        keychainStore: BilineKeychainCredentialStore? = nil,
        legacyFileStore: BilineCredentialFileStore? = nil,
        preferLegacyOnly: Bool = false
    ) {
        self.keychainStore =
            keychainStore
            ?? BilineKeychainCredentialStore(inputMethodBundleIdentifier: inputMethodBundleIdentifier)
        self.legacyFileStore =
            legacyFileStore
            ?? BilineCredentialFileStore(inputMethodBundleIdentifier: inputMethodBundleIdentifier)
        self.preferLegacyOnly = preferLegacyOnly
    }

    public func load() throws -> BilineAlibabaCredentialRecord {
        if preferLegacyOnly {
            return try legacyFileStore.load()
        }
        if let record = try? keychainStore.load() {
            return record
        }
        let legacy = try legacyFileStore.load()
        try? keychainStore.save(legacy)
        return legacy
    }

    public func loadIfAvailable() -> BilineAlibabaCredentialRecord? {
        if preferLegacyOnly {
            return legacyFileStore.loadIfAvailable()
        }
        if let record = try? keychainStore.load() {
            return record
        }
        if let legacy = legacyFileStore.loadIfAvailable() {
            try? keychainStore.save(legacy)
            return legacy
        }
        return nil
    }

    public func save(_ record: BilineAlibabaCredentialRecord) throws {
        if preferLegacyOnly {
            try legacyFileStore.save(record)
            return
        }
        try keychainStore.save(record)
    }

    public func clear() {
        if preferLegacyOnly {
            try? FileManager.default.removeItem(at: legacyFileStore.fileURL)
            return
        }
        keychainStore.clear()
        try? FileManager.default.removeItem(at: legacyFileStore.fileURL)
    }

    public func status() -> BilineCredentialFileStatus {
        if preferLegacyOnly {
            return legacyFileStore.status()
        }
        let keychainStatus = keychainStore.status()
        if keychainStatus.isComplete {
            return keychainStatus
        }
        let legacyStatus = legacyFileStore.status()
        if legacyStatus.isComplete {
            return BilineCredentialFileStatus(
                fileURL: keychainStatus.fileURL,
                accessKeyIdLength: legacyStatus.accessKeyIdLength,
                accessKeySecretLength: legacyStatus.accessKeySecretLength,
                loadError: nil
            )
        }
        return keychainStatus
    }
}
