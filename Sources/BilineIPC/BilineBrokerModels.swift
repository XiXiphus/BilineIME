import BilineOperations
import BilineSettings
import Foundation

public typealias BilineBrokerConfigurationSnapshot = BilineSharedConfigurationSnapshot

public enum BilineBrokerClientError: Error, LocalizedError {
    case noReply
    case timedOut
    case remoteError(String)
    case connectionUnavailable
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noReply:
            return "Broker did not reply."
        case .timedOut:
            return "Broker request timed out."
        case .remoteError(let message):
            return message
        case .connectionUnavailable:
            return "Broker connection unavailable."
        case .decodingFailed(let typeName):
            return "Failed to decode broker payload for \(typeName)."
        }
    }
}

public enum BilineBrokerNotification {
    public static let settingsDidChange = Notification.Name("io.github.xixiphus.BilineIME.dev.broker.settingsDidChange")
    public static let credentialsDidChange = Notification.Name("io.github.xixiphus.BilineIME.dev.broker.credentialsDidChange")
}
