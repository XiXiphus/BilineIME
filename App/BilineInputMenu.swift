import BilineSettings
import Cocoa
@preconcurrency import InputMethodKit
import OSLog

private let inputMenuLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "io.github.xixiphus.inputmethod.BilineIME",
    category: "input-menu"
)

extension BilineInputController {
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Biline 设置...",
                action: #selector(openBilineSettings(_:)),
                keyEquivalent: ""
            )
        )
        return menu
    }

    @objc func openBilineSettings(_ sender: Any?) {
        let url = BilineAppIdentifier.devSettingsOpenURL
        guard NSWorkspace.shared.open(url) else {
            inputMenuLogger.error(
                "Unable to open Biline Settings URL scheme=\(BilineAppIdentifier.devSettingsURLScheme, privacy: .public)"
            )
            return
        }
        inputMenuLogger.info(
            "Opened Biline Settings URL scheme=\(BilineAppIdentifier.devSettingsURLScheme, privacy: .public)"
        )
    }
}
