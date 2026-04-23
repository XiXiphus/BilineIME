import BilineSettings
import Cocoa

/// Visual theme for the candidate panel. Wraps `PanelThemeMode` (defined in
/// BilineSettings so the persisted enum has no AppKit dependency) with
/// `NSAppearance` ergonomics needed by the panel view.
struct PanelTheme: Sendable, Equatable {
    var mode: PanelThemeMode = .system
    var fontScale: Double = 1.0

    /// Returns an `NSAppearance` to push around drawing operations so that
    /// `NSColor` dynamic colors resolve to the chosen palette. `system`
    /// returns nil so the panel inherits the host's appearance.
    func appearance() -> NSAppearance? {
        switch mode {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    /// Clamp font scale to a reasonable range so a corrupt defaults value
    /// cannot blow up the panel size and starve the host of screen real
    /// estate.
    var clampedFontScale: CGFloat {
        let raw = fontScale.isFinite ? fontScale : 1.0
        return CGFloat(min(max(raw, 0.7), 1.8))
    }
}
