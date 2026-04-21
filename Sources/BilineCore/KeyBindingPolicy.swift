import Foundation

/// Identifies what an input event is being bound to, independent of which
/// physical key triggers it. The router asks the policy "is this event a
/// `nextRowOrPage` keystroke?" instead of comparing literal characters or
/// keycodes inline.
public enum KeyBindingRole: String, Sendable, Hashable, CaseIterable, Codable {
    /// Within compact composition, expand and advance to the next row; within
    /// expanded composition, browse to the next row (page-forwards at the end).
    case nextRowOrPage
    /// Within expanded composition, browse to the previous row (or collapse to
    /// compact when on the first row of the first page); from compact mode it
    /// either collapses (when expansion has happened earlier) or appends a
    /// literal punctuation glyph if the user remapped this role away.
    case previousRowOrPage
    /// Single-keystroke selection of the second visible candidate column.
    case candidate2
    /// Single-keystroke selection of the third visible candidate column.
    case candidate3
}

/// A single physical chord that can match an `InputControllerEvent`.
///
/// Either `keyCode` or `character` may be specified; if both are non-nil, both
/// must match. Modifier requirements default to "none required". If a chord
/// requires a modifier, the event must contain that modifier; if it does not
/// require a modifier, the event must not have command (shift is allowed when
/// not required, since most letter/punctuation chords are shift-agnostic).
public struct KeyChord: Sendable, Equatable, Hashable, Codable {
    public let character: String?
    public let keyCode: UInt16?
    public let requiresShift: Bool
    public let requiresCommand: Bool

    public init(
        character: String? = nil,
        keyCode: UInt16? = nil,
        requiresShift: Bool = false,
        requiresCommand: Bool = false
    ) {
        self.character = character
        self.keyCode = keyCode
        self.requiresShift = requiresShift
        self.requiresCommand = requiresCommand
    }
}

/// User-configurable key bindings for the input controller. Stored via the
/// settings store as a single Codable blob (one defaults key, not one per
/// binding) so that adding new roles in later milestones does not require new
/// `BilineDefaultsKey` entries or migration of existing keys.
public struct KeyBindingPolicy: Sendable, Equatable, Codable {
    public var bindings: [KeyBindingRole: [KeyChord]]

    public init(bindings: [KeyBindingRole: [KeyChord]] = [:]) {
        self.bindings = bindings
    }

    /// Returns the chords currently mapped to `role`. When the user has not
    /// configured anything for a role, falls back to the default policy so
    /// callers never see an unbound role at runtime.
    public func chords(for role: KeyBindingRole) -> [KeyChord] {
        if let configured = bindings[role], !configured.isEmpty {
            return configured
        }
        return KeyBindingPolicy.defaultChords[role] ?? []
    }

    /// The shipped defaults preserve today's behavior exactly: `=` and `]`
    /// drive forward row/page motion, `-` and `[` drive backwards row/page
    /// motion. Candidate2/3 ship empty by default so existing digit-selection
    /// (1-5) keeps working unchanged; Phase 1 turns on `;`/`'` from the
    /// Settings app.
    public static let `default` = KeyBindingPolicy(bindings: defaultChords)

    static let defaultChords: [KeyBindingRole: [KeyChord]] = [
        .nextRowOrPage: [
            KeyChord(character: "=", keyCode: 24),
            KeyChord(character: "]", keyCode: 30),
        ],
        .previousRowOrPage: [
            KeyChord(character: "-", keyCode: 27),
            KeyChord(character: "[", keyCode: 33),
        ],
        .candidate2: [],
        .candidate3: [],
    ]
}

extension KeyBindingPolicy {
    /// Round-trip helper for storing the policy as a property-list blob in
    /// `UserDefaults`/`CFPreferences`. We use JSON-via-Data instead of
    /// PropertyListSerialization so that the dictionary keys (which are role
    /// rawValues) survive cross-process writes without any custom `NSCoder`
    /// dance.
    public func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> KeyBindingPolicy {
        try JSONDecoder().decode(KeyBindingPolicy.self, from: data)
    }
}
