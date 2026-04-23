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

        let outputCapture = PipeOutputCapture(outputPipe.fileHandleForReading)
        let errorCapture = PipeOutputCapture(errorPipe.fileHandleForReading)
        let captureGroup = DispatchGroup()
        captureGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outputCapture.readToEnd()
            captureGroup.leave()
        }
        captureGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            errorCapture.readToEnd()
            captureGroup.leave()
        }

        do {
            try process.run()
        } catch {
            try? outputPipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForReading.close()
            captureGroup.wait()
            throw error
        }
        process.waitUntilExit()
        captureGroup.wait()

        let output = String(data: outputCapture.data, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorCapture.data, encoding: .utf8) ?? ""
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

private final class PipeOutputCapture: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private var capturedData = Data()

    init(_ handle: FileHandle) {
        self.handle = handle
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return capturedData
    }

    func readToEnd() {
        let data = handle.readDataToEndOfFile()
        lock.lock()
        capturedData = data
        lock.unlock()
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
