import BilineCore
import BilineSession
import XCTest

final class PostCommitTransformsTests: XCTestCase {
    private func context(
        previous: String? = nil,
        timestamp: Date? = nil,
        bundleID: String? = nil,
        form: PunctuationForm = .fullwidth
    ) -> PostCommitContext {
        PostCommitContext(
            lastCommittedText: previous,
            lastCommitTimestamp: timestamp,
            hostBundleID: bundleID,
            punctuationForm: form
        )
    }

    // MARK: - BracketAutoPairTransform

    func testBracketAutoPairAddsClosingBracket() {
        let transform = BracketAutoPairTransform()
        XCTAssertEqual(transform.transform("(", context: context()), "()")
        XCTAssertEqual(transform.transform("[", context: context()), "[]")
        XCTAssertEqual(transform.transform("{", context: context()), "{}")
        XCTAssertEqual(transform.transform("（", context: context()), "（）")
        XCTAssertEqual(transform.transform("「", context: context()), "「」")
    }

    func testBracketAutoPairLeavesNonBracketsAlone() {
        let transform = BracketAutoPairTransform()
        XCTAssertEqual(transform.transform("a", context: context()), "a")
        XCTAssertEqual(transform.transform(")", context: context()), ")")
        XCTAssertEqual(transform.transform("(x)", context: context()), "(x)")
    }

    // MARK: - SlashAsChineseEnumerationTransform

    func testSlashRewriteOnlyAppliesInFullwidthMode() {
        let transform = SlashAsChineseEnumerationTransform()
        XCTAssertEqual(transform.transform("/", context: context(form: .fullwidth)), "、")
        XCTAssertEqual(transform.transform("／", context: context(form: .fullwidth)), "、")
        XCTAssertEqual(transform.transform("/", context: context(form: .halfwidth)), "/")
        XCTAssertEqual(transform.transform("a", context: context(form: .fullwidth)), "a")
    }

    // MARK: - CrossScriptSpacingTransform

    func testCrossScriptSpacingAddsThinSpaceAtChineseEnglishBoundary() {
        let transform = CrossScriptSpacingTransform()
        let result = transform.transform(
            "hello", context: context(previous: "你好", timestamp: Date()))
        XCTAssertEqual(result, "\u{2009}hello")
    }

    func testCrossScriptSpacingAddsThinSpaceAtEnglishChineseBoundary() {
        let transform = CrossScriptSpacingTransform()
        let result = transform.transform(
            "你好", context: context(previous: "hello", timestamp: Date()))
        XCTAssertEqual(result, "\u{2009}你好")
    }

    func testCrossScriptSpacingSkipsWhenSameScript() {
        let transform = CrossScriptSpacingTransform()
        XCTAssertEqual(
            transform.transform(
                "world", context: context(previous: "hello", timestamp: Date())),
            "world"
        )
        XCTAssertEqual(
            transform.transform("世界", context: context(previous: "你好", timestamp: Date())),
            "世界"
        )
    }

    func testCrossScriptSpacingSkipsWhenBoundaryAlreadyHasSpace() {
        let transform = CrossScriptSpacingTransform()
        XCTAssertEqual(
            transform.transform(
                " hello", context: context(previous: "你好", timestamp: Date())),
            " hello"
        )
        XCTAssertEqual(
            transform.transform(
                "hello", context: context(previous: "你好 ", timestamp: Date())),
            "hello"
        )
    }

    func testCrossScriptSpacingExpiresAfterPause() {
        let transform = CrossScriptSpacingTransform()
        let stale = Date().addingTimeInterval(-30)
        let result = transform.transform(
            "hello", context: context(previous: "你好", timestamp: stale))
        XCTAssertEqual(result, "hello")
    }

    func testCrossScriptSpacingTreatsDigitsAsAscii() {
        let transform = CrossScriptSpacingTransform()
        XCTAssertEqual(
            transform.transform("123", context: context(previous: "数量", timestamp: Date())),
            "\u{2009}123"
        )
    }

    // MARK: - NumericPunctuationNormalizer

    func testColonAfterDigitNormalizesToHalfwidth() {
        let transform = NumericPunctuationNormalizer()
        XCTAssertEqual(
            transform.transform("：", context: context(previous: "12")),
            ":"
        )
        XCTAssertEqual(
            transform.transform(":", context: context(previous: "9")),
            ":"
        )
    }

    func testColonAfterNonDigitIsLeftAlone() {
        let transform = NumericPunctuationNormalizer()
        XCTAssertEqual(
            transform.transform("：", context: context(previous: "你好")),
            "："
        )
        XCTAssertEqual(
            transform.transform("：", context: context(previous: nil)),
            "："
        )
    }

    func testNonColonInputUntouched() {
        let transform = NumericPunctuationNormalizer()
        XCTAssertEqual(
            transform.transform("12", context: context(previous: "9")),
            "12"
        )
    }
}
