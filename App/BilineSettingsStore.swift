import BilineCore
import BilineIPC
import BilinePreview
import BilineSettings
import Foundation

/// App-side helper that constructs the runtime `LiveSettingsStore` against
/// the IME's own bundle identifier. Kept minimal so the actual store logic
/// (snapshot loading, change notification) stays in the BilineSettings
/// package where it can be unit tested without booting AppKit/IMK.
enum AppSettingsStore {
    static func make() -> LiveSettingsStore {
        let bundleIdentifier =
            Bundle.main.bundleIdentifier
            ?? BilineAppIdentifier.devInputMethodBundle
        let communicationHub = BilineCommunicationHub(inputMethodBundleIdentifier: bundleIdentifier)
        return LiveSettingsStore {
            communicationHub.loadConfiguration().settings
        }
    }
}
