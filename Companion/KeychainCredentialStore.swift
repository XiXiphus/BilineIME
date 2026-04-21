import BilinePreview
import Foundation
import Security

struct KeychainCredentialStatus {
    let accessKeyIDLength: Int?
    let accessKeySecretLength: Int?

    var isComplete: Bool {
        accessKeyIDLength != nil && accessKeySecretLength != nil
    }
}

struct KeychainCredentialStore {
    enum Account: String {
        case accessKeyID = "accessKeyId"
        case accessKeySecret = "accessKeySecret"
    }

    private let service = "BilineIME.AlibabaMachineTranslation"

    func store(_ value: String, account: Account) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainCredentialStoreError.securityStatus(addStatus)
        }
    }

    func credentials() -> AlibabaMachineTranslationCredentials? {
        guard let accessKeyID = password(account: .accessKeyID),
            let accessKeySecret = password(account: .accessKeySecret)
        else {
            return nil
        }
        return AlibabaMachineTranslationCredentials(
            accessKeyId: accessKeyID,
            accessKeySecret: accessKeySecret
        )
    }

    func status() -> KeychainCredentialStatus {
        KeychainCredentialStatus(
            accessKeyIDLength: password(account: .accessKeyID)?.count,
            accessKeySecretLength: password(account: .accessKeySecret)?.count
        )
    }

    private func password(account: Account) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
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

enum KeychainCredentialStoreError: Error {
    case securityStatus(OSStatus)
}
