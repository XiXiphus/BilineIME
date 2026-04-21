import BilineCore
import BilineSettings
import Foundation

extension BilineSettingsModel {
    func saveKeyBindings() {
        KeyBindingDefaults.save(keyBindings, into: defaultsStore)
        keyBindingsSaveStatus = "已保存"
        refresh()
    }

    func resetKeyBindingsToDefault() {
        keyBindings = .default
        saveKeyBindings()
    }

    /// Toggles a chord on or off for a given role. Used by the toggle-style
    /// rows in `KeyBindingSettingsView` so each setting row can stay
    /// declarative ("is this binding currently on?") instead of building the
    /// full policy by hand. Mutates `keyBindings` in place; the caller is
    /// expected to follow up with `saveKeyBindings()`.
    func setKeyBinding(role: KeyBindingRole, chords: [KeyChord], enabled: Bool) {
        var policy = keyBindings
        var current = policy.bindings[role] ?? KeyBindingPolicy.default.chords(for: role)
        if enabled {
            for chord in chords where !current.contains(chord) {
                current.append(chord)
            }
        } else {
            current.removeAll(where: { chords.contains($0) })
        }
        policy.bindings[role] = current
        keyBindings = policy
    }

    func isKeyBindingEnabled(role: KeyBindingRole, chords: [KeyChord]) -> Bool {
        let current = keyBindings.chords(for: role)
        return chords.allSatisfy { current.contains($0) }
    }
}
