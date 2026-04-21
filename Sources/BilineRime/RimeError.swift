import Foundation

enum RimeError: Error, LocalizedError {
    case missingLibrary(URL)
    case missingResource(String)
    case setupFailed(String)
    case deployFailed(String)
    case sessionCreateFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingLibrary(let url):
            return "Missing librime runtime at \(url.path)"
        case .missingResource(let name):
            return "Missing required Rime resource: \(name)"
        case .setupFailed(let message):
            return "Failed to initialize librime: \(message)"
        case .deployFailed(let message):
            return "Failed to deploy Rime schema: \(message)"
        case .sessionCreateFailed(let message):
            return "Failed to create Rime session: \(message)"
        }
    }
}
