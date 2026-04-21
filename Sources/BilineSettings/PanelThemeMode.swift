import Foundation

/// Visual mode for the candidate panel. Lives in BilineSettings (not the App)
/// so the settings snapshot stays free of AppKit and can be unit tested. The
/// App-level `PanelTheme` value type wraps this with `NSAppearance` ergonomics.
public enum PanelThemeMode: String, Sendable, Equatable, CaseIterable, Codable {
    case system
    case light
    case dark
}
