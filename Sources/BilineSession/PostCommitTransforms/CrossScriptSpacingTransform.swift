import BilineCore
import Foundation

/// Inserts a thin space between Chinese characters and ASCII letters/digits
/// when they meet at a commit boundary (either the previous commit ended in
/// one script and the new commit starts with the other, or vice versa).
/// We use U+2009 THIN SPACE rather than a regular space so the spacing reads
/// as a typographic hint and is easy to delete with a single backspace.
public struct CrossScriptSpacingTransform: PostCommitTransform {
    private static let thinSpace = "\u{2009}"
    /// Drop the rule when more than this much wall-clock time elapsed
    /// between commits — the user took a break, treat the new commit as a
    /// fresh sentence and skip the auto-space.
    private static let staleAfter: TimeInterval = 4.0

    public init() {}

    public func transform(_ text: String, context: PostCommitContext) -> String {
        guard let previous = context.lastCommittedText, !previous.isEmpty,
            !text.isEmpty
        else {
            return text
        }
        if let timestamp = context.lastCommitTimestamp,
            Date().timeIntervalSince(timestamp) > Self.staleAfter
        {
            return text
        }

        let previousLast = previous.last!
        let currentFirst = text.first!

        let previousIsChinese = isChinese(previousLast)
        let currentIsChinese = isChinese(currentFirst)
        let previousIsAsciiAlnum = isAsciiAlphanumeric(previousLast)
        let currentIsAsciiAlnum = isAsciiAlphanumeric(currentFirst)

        let crosses =
            (previousIsChinese && currentIsAsciiAlnum)
            || (previousIsAsciiAlnum && currentIsChinese)
        guard crosses else { return text }

        // Avoid double-spacing when the boundary already contains whitespace.
        if previousLast.isWhitespace || currentFirst.isWhitespace {
            return text
        }
        return Self.thinSpace + text
    }

    private func isChinese(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            let value = scalar.value
            // CJK Unified Ideographs (Basic) plus the most common extension blocks
            // we expect to see in user-committed text. Avoids pulling in CharacterSet
            // initialization on every keystroke.
            if (0x4E00...0x9FFF).contains(value)
                || (0x3400...0x4DBF).contains(value)
                || (0x20000...0x2A6DF).contains(value)
                || (0xF900...0xFAFF).contains(value)
            {
                return true
            }
        }
        return false
    }

    private func isAsciiAlphanumeric(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first,
            character.unicodeScalars.count == 1,
            scalar.isASCII
        else {
            return false
        }
        let value = scalar.value
        return (48...57).contains(value)
            || (65...90).contains(value)
            || (97...122).contains(value)
    }
}
