import BilineCore
import Foundation

/// Side-channel candidate source that produces emoji / kaomoji suggestions
/// from a pinyin string. Phase 4 milestone will plug a real implementation
/// (lexicon + ranker) into `RimeCandidateEngineSession` so emoji appear
/// alongside Chinese candidates without changing the Rime engine itself.
///
/// The protocol lives here ahead of that work so:
///   * the integration site (`RimeCandidateEngineSession.mapSnapshot`) has
///     a stable contract to call against;
///   * tests can stub out the matcher independently of librime startup;
///   * a no-op default keeps shipping behavior identical until the real
///     source is wired in.
public protocol EmojiCandidateSource: Sendable {
    /// Returns a small list (typically 0–3) of emoji candidates for the
    /// given normalized pinyin input. Implementations MUST be cheap to
    /// evaluate per keystroke and MUST NOT block the keystroke hot path.
    func candidates(forPinyin rawInput: String) -> [Candidate]
}

/// No-op default. Returns nothing for any input, keeping the candidate
/// list identical to a Rime-only build.
public struct EmptyEmojiCandidateSource: EmojiCandidateSource {
    public init() {}
    public func candidates(forPinyin rawInput: String) -> [Candidate] {
        []
    }
}
