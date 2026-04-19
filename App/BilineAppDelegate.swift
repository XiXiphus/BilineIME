import Cocoa
@preconcurrency import InputMethodKit
import OSLog

@main
final class BilineAppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.github.xixiphus.inputmethod.BilineIME",
        category: "app"
    )
    private(set) var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let connectionName =
            Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String
        server = IMKServer(
            name: connectionName,
            bundleIdentifier: Bundle.main.bundleIdentifier
        )
        logger.info(
            "BilineIME server initialized bundleIdentifier=\(Bundle.main.bundleIdentifier ?? "<nil>", privacy: .public) connectionName=\(connectionName ?? "<nil>", privacy: .public)"
        )
    }
}
