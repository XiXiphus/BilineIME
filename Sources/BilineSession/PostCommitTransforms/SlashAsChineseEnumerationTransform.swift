import BilineCore
import Foundation

/// Rewrites a committed slash to `、` (ideographic enumeration mark) when
/// the user is in Chinese punctuation mode. We accept either the raw ASCII
/// slash or the fullwidth `／` that `PunctuationPolicy` would otherwise
/// produce, because this transform runs after the punctuation-policy
/// rendering inside the post-commit pipeline.
public struct SlashAsChineseEnumerationTransform: PostCommitTransform {
    public init() {}

    public func transform(_ text: String, context: PostCommitContext) -> String {
        guard context.punctuationForm == .fullwidth else { return text }
        switch text {
        case "/", "／":
            return "、"
        default:
            return text
        }
    }
}
