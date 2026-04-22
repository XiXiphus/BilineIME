import BilineOperations
import Foundation

extension BilineCtl {
    static func run(arguments: [String]) throws -> String {
        guard let first = arguments.first else {
            throw BilineOperationError.unsupportedArguments(usage)
        }

        switch first {
        case "diagnose":
            let paths = BilineOperationPaths()
            guard arguments.dropFirst().first == "dev" else {
                throw BilineOperationError.unsupportedArguments(usage)
            }
            return DevEnvironmentDiagnostics(paths: paths).diagnosticReport()
        case "plan":
            return try plan(arguments: Array(arguments.dropFirst()))
        case "install":
            return try executeIntent(arguments: arguments, spec: parseInstallSpec(arguments: arguments))
        case "remove":
            return try executeIntent(arguments: arguments, spec: parseRemoveSpec(arguments: arguments))
        case "reset":
            return try executeIntent(arguments: arguments, spec: parseResetSpec(arguments: arguments))
        case "prepare-release":
            return try executeIntent(
                arguments: arguments,
                spec: parsePrepareReleaseSpec(arguments: arguments)
            )
        case "credentials":
            return try credentials(arguments: Array(arguments.dropFirst()))
        case "smoke-host":
            return try smokeHost(arguments: arguments)
        default:
            throw BilineOperationError.unsupportedArguments(usage)
        }
    }
}
