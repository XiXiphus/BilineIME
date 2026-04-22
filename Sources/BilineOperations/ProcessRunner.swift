import Foundation

public struct CommandResult: Sendable, Equatable {
    public let status: Int32
    public let output: String
    public let errorOutput: String
}

public protocol CommandRunning: Sendable {
    @discardableResult
    func run(_ executable: String, _ arguments: [String], allowFailure: Bool) throws
        -> CommandResult
    @discardableResult
    func runShell(_ command: String, allowFailure: Bool) throws -> CommandResult
}

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    @discardableResult
    public func run(_ executable: String, _ arguments: [String], allowFailure: Bool = false) throws
        -> CommandResult
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output =
            String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            ?? ""
        let errorOutput =
            String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            ?? ""
        let result = CommandResult(
            status: process.terminationStatus, output: output, errorOutput: errorOutput)
        if process.terminationStatus != 0 && !allowFailure {
            throw BilineOperationError.commandFailed(executable, arguments, result)
        }
        return result
    }

    @discardableResult
    public func runShell(_ command: String, allowFailure: Bool = false) throws -> CommandResult {
        try run("/bin/zsh", ["-lc", command], allowFailure: allowFailure)
    }
}

public enum BilineOperationError: Error, LocalizedError {
    case commandFailed(String, [String], CommandResult)
    case missingBuildProduct(URL)
    case confirmationRequiredForAction(String)
    case privilegedActionRequiresRoot(String)
    case unsupportedArguments(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let executable, let arguments, let result):
            return
                "Command failed: \(([executable] + arguments).joined(separator: " "))\n\(result.errorOutput)"
        case .missingBuildProduct(let url):
            return "Missing build product at \(url.path)"
        case .confirmationRequiredForAction(let action):
            return "\(action) requires --confirm."
        case .privilegedActionRequiresRoot(let action):
            return "\(action) requires root privileges."
        case .unsupportedArguments(let message):
            return message
        }
    }
}

func shellQuote(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}
