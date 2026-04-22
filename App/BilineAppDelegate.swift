import Cocoa
import BilineRime
import BilineSettings
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
        #if DEBUG
            BilineHostSmokeReporter.shared.record(
                .appLaunch,
                fields: [
                    "bundleIdentifier": Bundle.main.bundleIdentifier,
                    "connectionName": connectionName,
                ]
            )
        #endif
        prewarmRimeRuntime()
    }

    private func prewarmRimeRuntime() {
        let snapshot = AppSettingsStore.make().snapshot
        let logger = logger
        Task.detached(priority: .utility) {
            let startedAt = Date()
            logger.info(
                "Rime prewarm started fuzzyPinyinEnabled=\(snapshot.fuzzyPinyinEnabled, privacy: .public) characterForm=\(snapshot.characterForm.rawValue, privacy: .public)"
            )
            do {
                try BilinePinyinEngineFactory.prewarm(
                    fuzzyPinyinEnabled: snapshot.fuzzyPinyinEnabled,
                    characterForm: snapshot.characterForm
                )
                let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                logger.info("Rime prewarm finished elapsedMs=\(elapsedMs, privacy: .public)")
            } catch {
                logger.error("Rime prewarm failed error=\(String(describing: error), privacy: .public)")
            }
        }
    }
}
