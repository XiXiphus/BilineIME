import BilineCore
import XCTest

final class KeyBindingPolicyTests: XCTestCase {
    func testDefaultPolicyShipsExistingBindings() {
        let policy = KeyBindingPolicy.default

        let nextRowChars = policy.chords(for: .nextRowOrPage).compactMap(\.character)
        XCTAssertTrue(nextRowChars.contains("="))
        XCTAssertTrue(nextRowChars.contains("]"))

        let prevRowChars = policy.chords(for: .previousRowOrPage).compactMap(\.character)
        XCTAssertTrue(prevRowChars.contains("-"))
        XCTAssertTrue(prevRowChars.contains("["))

        // Candidate2/3 must be empty in the default so today's digit-1..5
        // candidate selection keeps working without surprise.
        XCTAssertTrue(policy.chords(for: .candidate2).isEmpty)
        XCTAssertTrue(policy.chords(for: .candidate3).isEmpty)
    }

    func testChordsForRoleFallsBackToDefaultWhenUnconfigured() {
        let policy = KeyBindingPolicy(bindings: [.candidate2: [KeyChord(character: ";")]])

        // Configured role uses user value.
        XCTAssertEqual(policy.chords(for: .candidate2).first?.character, ";")
        // Unconfigured role still returns shipped defaults.
        XCTAssertFalse(policy.chords(for: .nextRowOrPage).isEmpty)
    }

    func testEmptyChordListFallsBackToDefault() {
        // Empty array (e.g. user cleared bindings in settings) should not
        // leave the role unbound; we treat it as "use shipped default".
        let policy = KeyBindingPolicy(bindings: [.nextRowOrPage: []])
        XCTAssertFalse(policy.chords(for: .nextRowOrPage).isEmpty)
    }

    func testEncodeDecodeRoundTripsExactly() throws {
        let original = KeyBindingPolicy(bindings: [
            .candidate2: [KeyChord(character: ";")],
            .candidate3: [KeyChord(character: "'")],
            .nextRowOrPage: [KeyChord(character: ".", keyCode: 47)],
            .previousRowOrPage: [KeyChord(character: ",", keyCode: 43)],
        ])

        let data = try original.encode()
        let restored = try KeyBindingPolicy.decode(data)

        XCTAssertEqual(restored, original)
    }
}
