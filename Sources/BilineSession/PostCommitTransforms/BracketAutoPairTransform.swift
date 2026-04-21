import BilineCore
import Foundation

/// When the IME just committed a single opening bracket, this transform
/// appends the matching closing bracket. The caret stays after both glyphs
/// — IMK does not let the IME push the host caret backwards through text
/// storage in a portable way, so we honestly emit `()` instead of pretending
/// the cursor sits between them.
///
/// Recognized pairs are intentionally minimal so the transform never
/// surprises the user when typing a closing bracket on its own (e.g. when
/// finishing a math expression). The host's own auto-pair (Xcode, Notes)
/// will not double-pair because it sees both glyphs arrive together.
public struct BracketAutoPairTransform: PostCommitTransform {
    private static let pairs: [String: String] = [
        "(": ")",
        "[": "]",
        "{": "}",
        "（": "）",
        "【": "】",
        "「": "」",
        "『": "』",
        "“": "”",
        "‘": "’",
    ]

    public init() {}

    public func transform(_ text: String, context: PostCommitContext) -> String {
        guard text.count == 1, let closer = BracketAutoPairTransform.pairs[text] else {
            return text
        }
        return text + closer
    }
}
