import BilineOperations
import BilineSettings
import Foundation

public final class BilineBrokerClient {
    public let inputMethodBundleIdentifier: String
    public let machServiceName: String
    public let timeout: TimeInterval

    public init(
        inputMethodBundleIdentifier: String = BilineAppIdentifier.devInputMethodBundle,
        timeout: TimeInterval = 2.0
    ) {
        self.inputMethodBundleIdentifier = inputMethodBundleIdentifier
        self.machServiceName = BilineSharedIdentifier.brokerMachServiceName(
            for: inputMethodBundleIdentifier
        )
        self.timeout = timeout
    }

    public func ping() throws -> String {
        try requestString { proxy, reply in
            proxy.ping(reply)
        }
    }

    public func fetchConfiguration() throws -> BilineBrokerConfigurationSnapshot {
        try requestDecodable(BilineBrokerConfigurationSnapshot.self) { proxy, reply in
            proxy.fetchConfiguration(reply)
        }
    }

    public func storeConfiguration(_ snapshot: BilineBrokerConfigurationSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try requestVoid { proxy, reply in
            proxy.storeConfiguration(data, reply: reply)
        }
    }

    public func fetchCredentialStatus() throws -> BilineCredentialFileStatus {
        try requestDecodable(BilineCredentialFileStatus.self) { proxy, reply in
            proxy.fetchCredentialStatus(reply)
        }
    }

    public func loadCredentialRecord() throws -> BilineAlibabaCredentialRecord {
        try requestDecodable(BilineAlibabaCredentialRecord.self) { proxy, reply in
            proxy.loadCredentialRecord(reply)
        }
    }

    public func saveCredentialRecord(_ record: BilineAlibabaCredentialRecord) throws {
        let data = try JSONEncoder().encode(record)
        try requestVoid { proxy, reply in
            proxy.saveCredentialRecord(data, reply: reply)
        }
    }

    public func clearCredentialRecord() throws {
        try requestVoid { proxy, reply in
            proxy.clearCredentialRecord(reply)
        }
    }

    public func fetchDiagnostics() throws -> DevEnvironmentSnapshot {
        try requestDecodable(DevEnvironmentSnapshot.self) { proxy, reply in
            proxy.fetchDiagnostics(reply)
        }
    }

    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: machServiceName, options: [])
        connection.remoteObjectInterface = NSXPCInterface(with: BilineBrokerXPCProtocol.self)
        connection.resume()
        return connection
    }

    private func requestString(
        _ invoke: (BilineBrokerXPCProtocol, @escaping (String) -> Void) -> Void
    ) throws -> String {
        let connection = makeConnection()
        defer { connection.invalidate() }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in }) as? BilineBrokerXPCProtocol else {
            throw BilineBrokerClientError.connectionUnavailable
        }

        let semaphore = DispatchSemaphore(value: 0)
        var value: String?
        invoke(proxy) {
            value = $0
            semaphore.signal()
        }
        let result = semaphore.wait(timeout: .now() + timeout)
        guard result == .success else { throw BilineBrokerClientError.timedOut }
        guard let value else { throw BilineBrokerClientError.noReply }
        return value
    }

    private func requestVoid(
        _ invoke: (BilineBrokerXPCProtocol, @escaping (String?) -> Void) -> Void
    ) throws {
        let connection = makeConnection()
        defer { connection.invalidate() }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in }) as? BilineBrokerXPCProtocol else {
            throw BilineBrokerClientError.connectionUnavailable
        }

        let semaphore = DispatchSemaphore(value: 0)
        var remoteError: String?
        invoke(proxy) {
            remoteError = $0
            semaphore.signal()
        }
        let result = semaphore.wait(timeout: .now() + timeout)
        guard result == .success else { throw BilineBrokerClientError.timedOut }
        if let remoteError {
            throw BilineBrokerClientError.remoteError(remoteError)
        }
    }

    private func requestDecodable<T: Decodable>(
        _ type: T.Type,
        invoke: (BilineBrokerXPCProtocol, @escaping (Data?, String?) -> Void) -> Void
    ) throws -> T {
        let connection = makeConnection()
        defer { connection.invalidate() }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in }) as? BilineBrokerXPCProtocol else {
            throw BilineBrokerClientError.connectionUnavailable
        }

        let semaphore = DispatchSemaphore(value: 0)
        var payload: Data?
        var remoteError: String?
        invoke(proxy) { data, error in
            payload = data
            remoteError = error
            semaphore.signal()
        }
        let result = semaphore.wait(timeout: .now() + timeout)
        guard result == .success else { throw BilineBrokerClientError.timedOut }
        if let remoteError {
            throw BilineBrokerClientError.remoteError(remoteError)
        }
        guard let payload else { throw BilineBrokerClientError.noReply }
        do {
            return try JSONDecoder().decode(type, from: payload)
        } catch {
            throw BilineBrokerClientError.decodingFailed(String(describing: type))
        }
    }
}
