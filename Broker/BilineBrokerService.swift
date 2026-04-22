import BilineIPC
import BilineOperations
import BilineSettings
import Foundation

final class BilineBrokerService: NSObject, BilineBrokerXPCProtocol {
    private let inputMethodBundleIdentifier = BilineAppIdentifier.devInputMethodBundle
    private lazy var configurationStore = BilineSharedConfigurationStore(
        inputMethodBundleIdentifier: inputMethodBundleIdentifier
    )
    private lazy var credentialStore = BilineCredentialVault(
        inputMethodBundleIdentifier: inputMethodBundleIdentifier
    )

    func ping(_ reply: @escaping (String) -> Void) {
        reply("ok")
    }

    func fetchConfiguration(_ reply: @escaping (Data?, String?) -> Void) {
        encode(configurationStore.load(), reply: reply)
    }

    func storeConfiguration(_ data: Data, reply: @escaping (String?) -> Void) {
        do {
            let snapshot = try JSONDecoder().decode(BilineBrokerConfigurationSnapshot.self, from: data)
            configurationStore.save(snapshot)
            DistributedNotificationCenter.default().post(name: BilineBrokerNotification.settingsDidChange, object: nil)
            reply(nil)
        } catch {
            reply(error.localizedDescription)
        }
    }

    func fetchCredentialStatus(_ reply: @escaping (Data?, String?) -> Void) {
        encode(credentialStore.status(), reply: reply)
    }

    func loadCredentialRecord(_ reply: @escaping (Data?, String?) -> Void) {
        do {
            let record = try credentialStore.load()
            encode(record, reply: reply)
        } catch {
            reply(nil, error.localizedDescription)
        }
    }

    func saveCredentialRecord(_ data: Data, reply: @escaping (String?) -> Void) {
        do {
            let record = try JSONDecoder().decode(BilineAlibabaCredentialRecord.self, from: data)
            try credentialStore.save(record)
            DistributedNotificationCenter.default().post(name: BilineBrokerNotification.credentialsDidChange, object: nil)
            reply(nil)
        } catch {
            reply(error.localizedDescription)
        }
    }

    func clearCredentialRecord(_ reply: @escaping (String?) -> Void) {
        credentialStore.clear()
        DistributedNotificationCenter.default().post(name: BilineBrokerNotification.credentialsDidChange, object: nil)
        reply(nil)
    }

    func fetchDiagnostics(_ reply: @escaping (Data?, String?) -> Void) {
        encode(DevEnvironmentDiagnostics().snapshot(), reply: reply)
    }

    private func encode<T: Encodable>(
        _ value: T,
        reply: @escaping (Data?, String?) -> Void
    ) {
        do {
            let data = try JSONEncoder().encode(value)
            reply(data, nil)
        } catch {
            reply(nil, error.localizedDescription)
        }
    }
}
