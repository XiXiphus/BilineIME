import BilineCore
import Foundation

extension KeyChord {
    /// Returns true when `event` satisfies this chord's key/modifier
    /// requirements. Either `keyCode` or `character` may be specified; if both
    /// are provided, both must match. Modifier semantics:
    ///
    /// - `requiresShift` / `requiresCommand`: when true, the corresponding
    ///   modifier must be present in `event.modifierFlags`. The router relies
    ///   on these to model `shift+tab` style chords.
    /// - When `requiresCommand` is false, the chord refuses to match a
    ///   command-modified event. Command-key combinations are reserved for
    ///   the host (Cmd+C / Cmd+V / Cmd+Q etc.) and must never be silently
    ///   absorbed by the router.
    public func matches(event: InputControllerEvent) -> Bool {
        if event.modifierFlags.contains(.command) != requiresCommand {
            return false
        }
        if requiresShift, !event.modifierFlags.contains(.shift) {
            return false
        }

        if let keyCode {
            if event.keyCode != keyCode {
                return false
            }
        }

        if let character {
            // Compare against the *actually produced* character so that
            // shift-modified glyphs (Shift+`-` → `_`, Shift+`=` → `+`,
            // Shift+`]` → `}`) do not silently match a chord bound to the
            // unshifted key. We fall back to charactersIgnoringModifiers
            // only when the event has no characters at all (e.g. dead
            // arrow keys), preserving keyCode-only chord matching.
            let produced = event.characters ?? event.charactersIgnoringModifiers
            if produced != character {
                return false
            }
        }

        return keyCode != nil || character != nil
    }
}

extension KeyBindingPolicy {
    /// Returns true if any chord bound to `role` matches `event`.
    public func matches(role: KeyBindingRole, event: InputControllerEvent) -> Bool {
        chords(for: role).contains { $0.matches(event: event) }
    }
}
