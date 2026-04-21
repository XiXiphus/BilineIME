import BilineCore
import Foundation

/// When the IME just committed a colon (either ASCII `:` or fullwidth `：`)
/// and the previous commit ended with a digit, AND the user is about to type
/// the next digit, the host text reads "12: 0" because the space comes from
/// fullwidth punctuation. WeChat IME's "符号自动转换" feature collapses that
/// into "12:00" by removing the surrounding fullwidth space and switching
/// the colon to its half-width form.
///
/// This transform is the boundary-collapsing half of that behaviour: when a
/// colon is committed right after a digit, force half-width punctuation for
/// the colon itself. The post-commit history (digit -> colon) is enough
/// signal; we do not need to inspect the upcoming digit because the next
/// digit's commit will simply be a digit (not punctuation), with no
/// fullwidth space attached.
public struct NumericPunctuationNormalizer: PostCommitTransform {
    public init() {}

    public func transform(_ text: String, context: PostCommitContext) -> String {
        guard isColon(text), let previous = context.lastCommittedText,
            let lastChar = previous.last,
            isAsciiDigit(lastChar)
        else {
            return text
        }
        return ":"
    }

    private func isColon(_ text: String) -> Bool {
        text == ":" || text == "："
    }

    private func isAsciiDigit(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first,
            character.unicodeScalars.count == 1
        else {
            return false
        }
        return (48...57).contains(scalar.value)
    }
}
