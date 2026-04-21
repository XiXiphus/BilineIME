import BilineCore
import Foundation

/// Context passed to every `PostCommitTransform`. Carries enough about the
/// previous commit and current settings for transforms (auto-spacing,
/// auto-numbering, numeric-colon normalization) to make a decision without
/// reaching back into the session's mutable state.
public struct PostCommitContext: Sendable, Equatable {
    /// Text the IME just emitted before the current commit. Nil when this is
    /// the first commit since the session started.
    public let lastCommittedText: String?
    /// Wall-clock time of the previous commit. Transforms use this to expire
    /// stale "last commit" relationships (e.g. don't auto-space if the user
    /// paused for several seconds between commits).
    public let lastCommitTimestamp: Date?
    /// Bundle identifier of the focused host app. Captured by the controller
    /// at commit time. Nil when the host did not expose one.
    public let hostBundleID: String?
    /// Resolved punctuation form for the current commit, mirrored here so
    /// transforms do not need to thread a `SettingsStore` through.
    public let punctuationForm: PunctuationForm
    /// Most recent commits in chronological order, oldest first. Capped at
    /// `commitHistoryLimit` (currently 4) so memory stays bounded over a
    /// long session. Future transforms (e.g. Phase 4 auto-numbering) walk
    /// this list to detect multi-step patterns like `1.` → newline → next
    /// committed item.
    public let commitHistory: [String]

    public static let commitHistoryLimit = 4

    public init(
        lastCommittedText: String?,
        lastCommitTimestamp: Date?,
        hostBundleID: String?,
        punctuationForm: PunctuationForm,
        commitHistory: [String] = []
    ) {
        self.lastCommittedText = lastCommittedText
        self.lastCommitTimestamp = lastCommitTimestamp
        self.hostBundleID = hostBundleID
        self.punctuationForm = punctuationForm
        self.commitHistory = commitHistory
    }
}

/// A single transformation applied to text the IME is about to commit into
/// the host. Transforms are pure: they take text + context, return new text.
/// They MUST be cheap (run on the keystroke hot path) and order-independent
/// from the user's perspective when at all possible.
public protocol PostCommitTransform: Sendable {
    func transform(_ text: String, context: PostCommitContext) -> String
}

/// Ordered chain of transforms. Phase 0 ships an empty pipeline so behavior
/// is identical to before; Phase 2+ features (CN/EN spacing, numeric colon
/// normalization, etc.) attach themselves as new transforms.
public final class PostCommitPipeline: @unchecked Sendable {
    private let transforms: [any PostCommitTransform]

    public init(_ transforms: [any PostCommitTransform] = []) {
        self.transforms = transforms
    }

    public func apply(_ text: String, context: PostCommitContext) -> String {
        transforms.reduce(text) { partial, transform in
            transform.transform(partial, context: context)
        }
    }

    public var isEmpty: Bool { transforms.isEmpty }

    public static let empty = PostCommitPipeline()
}
