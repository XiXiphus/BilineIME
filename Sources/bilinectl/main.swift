import BilineOperations
import Foundation

@main
struct BilineCtl {
    static func main() {
        do {
            let output = try run(arguments: Array(CommandLine.arguments.dropFirst()))
            if !output.isEmpty {
                print(output)
            }
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    static func run(arguments: [String]) throws -> String {
        guard let first = arguments.first else {
            throw BilineOperationError.unsupportedArguments(usage)
        }

        let paths = BilineOperationPaths()
        switch first {
        case "diagnose":
            guard arguments.dropFirst().first == "dev" else {
                throw BilineOperationError.unsupportedArguments(usage)
            }
            return DevEnvironmentDiagnostics(paths: paths).diagnosticReport()
        case "plan":
            return try plan(arguments: Array(arguments.dropFirst()), paths: paths)
        case "reinstall":
            return try reinstall(arguments: arguments, paths: paths)
        default:
            throw BilineOperationError.unsupportedArguments(usage)
        }
    }

    private static func plan(arguments: [String], paths: BilineOperationPaths) throws -> String {
        guard arguments.count >= 2, arguments[0] == "reinstall", arguments[1] == "dev" else {
            throw BilineOperationError.unsupportedArguments(usage)
        }
        let level = try parseLevel(arguments)
        return DevReinstallPlanner(paths: paths).plan(level: level).rendered
    }

    private static func reinstall(arguments: [String], paths: BilineOperationPaths) throws -> String
    {
        guard arguments.count >= 2, arguments[0] == "reinstall", arguments[1] == "dev" else {
            throw BilineOperationError.unsupportedArguments(usage)
        }
        let level = try parseLevel(arguments)
        let confirmed = arguments.contains("--confirm")
        return try DevLifecycleInstaller(paths: paths).reinstall(level: level, confirmed: confirmed)
    }

    private static func parseLevel(_ arguments: [String]) throws -> BilineOperationLevel {
        guard let levelFlagIndex = arguments.firstIndex(of: "--level"),
            arguments.indices.contains(arguments.index(after: levelFlagIndex)),
            let level = BilineOperationLevel(
                rawArgument: arguments[arguments.index(after: levelFlagIndex)])
        else {
            throw BilineOperationError.unsupportedArguments(
                "Missing or invalid --level 1|2|3.\n\(usage)")
        }
        return level
    }

    private static let usage = """
        usage:
          bilinectl diagnose dev
          bilinectl plan reinstall dev --level 1|2|3
          bilinectl reinstall dev --level 1|2|3 --confirm
        """
}
