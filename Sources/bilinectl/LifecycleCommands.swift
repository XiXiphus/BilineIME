import BilineOperations
import Foundation

extension BilineCtl {
    static func plan(arguments: [String]) throws -> String {
        let homeDirectory = try parseHomeDirectory(arguments)
        let paths = BilineOperationPaths(homeDirectory: homeDirectory)
        let spec = try parsePlanSpec(arguments)
        return LifecycleOperationPlanner(paths: paths).plan(spec).rendered
    }

    static func parsePlanSpec(_ arguments: [String]) throws -> LifecycleOperationSpec {
        guard let first = arguments.first else {
            throw BilineOperationError.unsupportedArguments(usage)
        }
        switch first {
        case "install":
            return try parseInstallSpec(arguments: arguments)
        case "remove":
            return try parseRemoveSpec(arguments: arguments)
        case "reset":
            return try parseResetSpec(arguments: arguments)
        case "prepare-release":
            return try parsePrepareReleaseSpec(arguments: arguments)
        default:
            throw BilineOperationError.unsupportedArguments(usage)
        }
    }

    static func parseInstallSpec(arguments: [String]) throws -> LifecycleOperationSpec {
        guard arguments.count >= 2, arguments[0] == "install", arguments[1] == "dev" else {
            throw BilineOperationError.unsupportedArguments(usage)
        }
        return .install(scope: try parseScope(arguments, default: .user))
    }

    static func parseRemoveSpec(arguments: [String]) throws -> LifecycleOperationSpec {
        guard arguments.count >= 2, arguments[0] == "remove", arguments[1] == "dev" else {
            throw BilineOperationError.unsupportedArguments(usage)
        }
        return .remove(
            scope: try parseScope(arguments, default: .user),
            dataPolicy: try parseDataPolicy(arguments)
        )
    }

    static func parseResetSpec(arguments: [String]) throws -> LifecycleOperationSpec {
        guard arguments.count >= 2, arguments[0] == "reset", arguments[1] == "dev" else {
            throw BilineOperationError.unsupportedArguments(usage)
        }
        return .reset(
            scope: try parseScope(arguments, default: .all),
            depth: try parseResetDepth(arguments)
        )
    }

    static func parsePrepareReleaseSpec(arguments: [String]) throws -> LifecycleOperationSpec {
        guard arguments.count >= 2, arguments[0] == "prepare-release", arguments[1] == "dev" else {
            throw BilineOperationError.unsupportedArguments(usage)
        }
        return .prepareRelease(scope: try parseScope(arguments, default: .all))
    }

    static func executeIntent(
        arguments: [String],
        spec: LifecycleOperationSpec
    ) throws -> String {
        let confirmed = arguments.contains("--confirm")
        let homeDirectory = try parseHomeDirectory(arguments)
        let paths = BilineOperationPaths(homeDirectory: homeDirectory)
        return try LifecycleOperationExecutor(paths: paths).apply(spec, confirmed: confirmed)
    }
}
