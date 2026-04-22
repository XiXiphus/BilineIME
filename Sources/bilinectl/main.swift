import Darwin
import Foundation

struct BilineCtl {}

do {
    let output = try BilineCtl.run(arguments: Array(CommandLine.arguments.dropFirst()))
    if !output.isEmpty {
        print(output)
    }
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
