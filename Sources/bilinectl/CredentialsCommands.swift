import BilineOperations
import BilineSettings
import Darwin
import Foundation

extension BilineCtl {
    static func credentials(arguments: [String]) throws -> String {
        guard arguments.count >= 2, arguments[1] == "dev" else {
            throw BilineOperationError.unsupportedArguments(usage)
        }

        let operations = AlibabaCredentialOperations()
        switch arguments[0] {
        case "status":
            return operations.statusReport()
        case "configure":
            let record = BilineAlibabaCredentialRecord(
                accessKeyId: readHiddenLine(prompt: "Alibaba AccessKey ID: "),
                accessKeySecret: readHiddenLine(prompt: "Alibaba AccessKey Secret: "),
                regionId: readPlainLine(
                    prompt: "Alibaba region",
                    fallback: AlibabaCredentialOperations.defaultRegionId),
                endpoint: readPlainLine(
                    prompt: "Alibaba endpoint",
                    fallback: AlibabaCredentialOperations.defaultEndpoint)
            )
            return try operations.configure(record: record)
        case "clear":
            return operations.clear()
        default:
            throw BilineOperationError.unsupportedArguments(usage)
        }
    }

    static func readHiddenLine(prompt: String) -> String {
        fputs(prompt, stderr)

        var original = termios()
        let hasTerminal = tcgetattr(STDIN_FILENO, &original) == 0
        if hasTerminal {
            var hidden = original
            hidden.c_lflag &= ~tcflag_t(ECHO)
            tcsetattr(STDIN_FILENO, TCSANOW, &hidden)
        }

        let value = readLine() ?? ""

        if hasTerminal {
            tcsetattr(STDIN_FILENO, TCSANOW, &original)
        }
        fputs("\n", stderr)
        return value
    }

    static func readPlainLine(prompt: String, fallback: String) -> String {
        fputs("\(prompt) [\(fallback)]: ", stderr)
        let value = readLine() ?? ""
        return value.isEmpty ? fallback : value
    }
}
