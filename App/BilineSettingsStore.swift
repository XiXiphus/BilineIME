import BilineCore
import BilinePreview
import BilineSettings
import Foundation

/// App-side helper that constructs the runtime `LiveSettingsStore` against
/// the IME's own bundle identifier. Kept minimal so the actual store logic
/// (snapshot loading, change notification) stays in the BilineSettings
/// package where it can be unit tested without booting AppKit/IMK.
enum AppSettingsStore {
    static func make() -> LiveSettingsStore {
        let domain =
            Bundle.main.bundleIdentifier
            ?? BilineAppIdentifier.devInputMethodBundle
        return LiveSettingsStore(domain: domain)
    }
}
