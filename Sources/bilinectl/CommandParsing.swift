import BilineOperations
import Foundation

extension BilineCtl {
    static func parseScope(
        _ arguments: [String],
        default defaultScope: LifecycleScope
    ) throws -> LifecycleScope {
        guard let value = try value(forFlag: "--scope", in: arguments) else {
            return defaultScope
        }
        guard let surface = LifecycleScope(rawValue: value) else {
            throw BilineOperationError.unsupportedArguments(
                "Missing or invalid --scope user|system|all.\n\(usage)")
        }
        return surface
    }

    static func parseHomeDirectory(_ arguments: [String]) throws -> URL {
        guard let value = try value(forFlag: "--home", in: arguments) else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        let path = (value as NSString).expandingTildeInPath
        guard !path.isEmpty else {
            throw BilineOperationError.unsupportedArguments(
                "Missing value for --home.\n\(usage)")
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func value(forFlag flag: String, in arguments: [String]) throws -> String? {
        guard let flagIndex = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            throw BilineOperationError.unsupportedArguments(
                "Missing value for \(flag).\n\(usage)")
        }
        return arguments[valueIndex]
    }

    static func parseDataPolicy(_ arguments: [String]) throws -> LifecycleDataPolicy {
        guard let value = try value(forFlag: "--data", in: arguments) else {
            return .preserve
        }
        guard let policy = LifecycleDataPolicy(rawValue: value) else {
            throw BilineOperationError.unsupportedArguments(
                "Missing or invalid --data preserve|purge.\n\(usage)")
        }
        return policy
    }

    static func parseResetDepth(_ arguments: [String]) throws -> LifecycleResetDepth {
        guard let value = try value(forFlag: "--depth", in: arguments) else {
            throw BilineOperationError.unsupportedArguments(
                "Missing or invalid --depth refresh|cache-prune|launch-services-reset.\n\(usage)")
        }
        guard let depth = LifecycleResetDepth(rawValue: value) else {
            throw BilineOperationError.unsupportedArguments(
                "Missing or invalid --depth refresh|cache-prune|launch-services-reset.\n\(usage)")
        }
        return depth
    }
}
