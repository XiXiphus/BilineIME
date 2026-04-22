import BilineOperations
import BilineSettings
import Foundation

public final class BilineCommunicationHub: @unchecked Sendable {
    public let inputMethodBundleIdentifier: String
    public let brokerClient: BilineBrokerClient
    public let configurationStore: BilineSharedConfigurationStore
    public let credentialVault: BilineCredentialVault
    public let diagnostics: DevEnvironmentDiagnostics

    public init(
        inputMethodBundleIdentifier: String = BilineAppIdentifier.devInputMethodBundle,
        brokerClient: BilineBrokerClient? = nil,
        configurationStore: BilineSharedConfigurationStore? = nil,
        credentialVault: BilineCredentialVault? = nil,
        diagnostics: DevEnvironmentDiagnostics = DevEnvironmentDiagnostics()
    ) {
        self.inputMethodBundleIdentifier = inputMethodBundleIdentifier
        self.brokerClient =
            brokerClient ?? BilineBrokerClient(inputMethodBundleIdentifier: inputMethodBundleIdentifier)
        self.configurationStore =
            configurationStore ?? BilineSharedConfigurationStore(
                inputMethodBundleIdentifier: inputMethodBundleIdentifier
            )
        self.credentialVault =
            credentialVault ?? BilineCredentialVault(inputMethodBundleIdentifier: inputMethodBundleIdentifier)
        self.diagnostics = diagnostics
    }

    public func loadConfiguration() -> BilineBrokerConfigurationSnapshot {
        (try? brokerClient.fetchConfiguration()) ?? configurationStore.load()
    }

    public func saveConfiguration(_ snapshot: BilineBrokerConfigurationSnapshot) throws {
        do {
            try brokerClient.storeConfiguration(snapshot)
        } catch {
            configurationStore.save(snapshot)
        }
    }

    public func credentialStatus() -> BilineCredentialFileStatus {
        (try? brokerClient.fetchCredentialStatus()) ?? credentialVault.status()
    }

    public func loadCredentialRecord() throws -> BilineAlibabaCredentialRecord {
        do {
            return try brokerClient.loadCredentialRecord()
        } catch {
            return try credentialVault.load()
        }
    }

    public func saveCredentialRecord(_ record: BilineAlibabaCredentialRecord) throws {
        do {
            try brokerClient.saveCredentialRecord(record)
        } catch {
            try credentialVault.save(record)
        }
    }

    public func clearCredentialRecord() {
        do {
            try brokerClient.clearCredentialRecord()
        } catch {
            credentialVault.clear()
        }
    }

    public func diagnosticsSnapshot() -> DevEnvironmentSnapshot {
        (try? brokerClient.fetchDiagnostics()) ?? diagnostics.snapshot()
    }
}
