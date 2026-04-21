import BilineSession
import BilineSettings

/// Translates a `SettingsSnapshot` into a concrete `PostCommitPipeline`.
///
/// Order matters: `BracketAutoPair` runs first because it can extend a
/// single-character commit (`(` -> `()`); `SlashAsChineseEnumeration`
/// rewrites a slash before any later transform sees it; the numeric colon
/// normalizer must run before `CrossScriptSpacing` so the spacing rule sees
/// the canonical half-width colon when deciding whether a thin space is
/// needed.
enum PostCommitPipelineBuilder {
    static func build(from snapshot: SettingsSnapshot) -> PostCommitPipeline {
        var transforms: [any PostCommitTransform] = []
        if snapshot.autoPairBrackets {
            transforms.append(BracketAutoPairTransform())
        }
        if snapshot.slashAsChineseEnumeration {
            transforms.append(SlashAsChineseEnumerationTransform())
        }
        if snapshot.normalizeNumericColon {
            transforms.append(NumericPunctuationNormalizer())
        }
        if snapshot.autoSpaceBetweenChineseAndAscii {
            transforms.append(CrossScriptSpacingTransform())
        }
        return PostCommitPipeline(transforms)
    }
}
