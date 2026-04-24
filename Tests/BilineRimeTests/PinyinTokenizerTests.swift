import BilineCore
import XCTest

@testable import BilineRime

final class PinyinTokenizerTests: XCTestCase {
    private func writeTemporaryDictionary(_ body: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BilinePinyinTokenizerTests-")
            .appendingPathExtension(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("test.dict.yaml")
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testTokenizeAllKeepsAmbiguousModernPinyinSegmentations() {
        let tokenizer = PinyinTokenizer(syllables: ["xian", "xi", "an"])

        let segmentations = tokenizer.tokenizeAll("xian")

        XCTAssertTrue(segmentations.contains(["xian"]))
        XCTAssertTrue(segmentations.contains(["xi", "an"]))
    }

    func testSharedSegmenterUsesGreedyBlocksForRawCursorNavigation() {
        let segmenter = PinyinInputSegmenter()

        XCTAssertEqual(segmenter.blockBoundaries(in: "haopingguo"), [0, 3, 7, 10])
        XCTAssertEqual(segmenter.blockBoundaries(in: "xian"), [0, 4])
        XCTAssertEqual(segmenter.blockBoundaries(in: "xi'an"), [0, 3, 5])
        XCTAssertEqual(segmenter.previousBlockBoundary(in: "haopingguo", from: 10), 7)
        XCTAssertEqual(segmenter.nextBlockBoundary(in: "haopingguo", from: 3), 7)
    }

    func testLexiconConsumptionUsesSurfaceToResolveAmbiguousSegmentation() throws {
        let url = try writeTemporaryDictionary(
            """
            # Rime dictionary
            # encoding: utf-8

            ---
            name: test
            version: "0.1"
            sort: by_weight
            ...

            西安\txi an\t200
            先\txian\t100
            好\thao\t100
            好苹果\thao ping guo\t300
            苹果\tping guo\t200
            苹果公司\tping guo gong si\t250
            """
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let tokenizer = try PinyinTokenizer.fromDictionaryFile(at: url)
        let lexicon = try RimeLexicon.fromDictionaryFiles(at: [url])

        XCTAssertEqual(
            lexicon.consumption(
                forSurface: "西安", rawInput: "xian", comment: nil, tokenizer: tokenizer),
            RimeConsumption(tokenCount: 2, tokens: ["xi", "an"])
        )
        XCTAssertEqual(
            lexicon.consumption(
                forSurface: "先", rawInput: "xian", comment: nil, tokenizer: tokenizer),
            RimeConsumption(tokenCount: 1, tokens: ["xian"])
        )
        XCTAssertEqual(
            lexicon.consumption(
                forSurface: "好", rawInput: "haopingguo", comment: nil, tokenizer: tokenizer),
            RimeConsumption(tokenCount: 1, tokens: ["hao", "ping", "guo"])
        )
        XCTAssertEqual(
            lexicon.consumption(
                forSurface: "好苹果", rawInput: "haopingguo", comment: nil, tokenizer: tokenizer),
            RimeConsumption(tokenCount: 3, tokens: ["hao", "ping", "guo"])
        )
        XCTAssertEqual(
            lexicon.consumption(
                forSurface: "好苹果", rawInput: "hpg", comment: nil, tokenizer: tokenizer),
            RimeConsumption(tokenCount: 3, tokens: ["h", "p", "g"])
        )
        XCTAssertEqual(
            lexicon.consumption(
                forSurface: "好", rawInput: "hpg", comment: nil, tokenizer: tokenizer),
            RimeConsumption(tokenCount: 1, tokens: ["h", "p", "g"])
        )
        XCTAssertEqual(
            lexicon.consumption(
                forSurface: "苹果公司",
                rawInput: "pingguogs",
                comment: nil,
                tokenizer: tokenizer
            ),
            RimeConsumption(tokenCount: 4, tokens: ["ping", "guo", "g", "s"])
        )
    }

    func testToneMarkedPinyinNormalizesToAsciiInputForm() {
        let tokenizer = PinyinTokenizer(syllables: ["lv", "xing"])

        XCTAssertEqual(tokenizer.readingTokens(from: "lǚ xíng") ?? [], ["lv", "xing"])
        XCTAssertEqual(PinyinTokenizer.normalizeInput("Lǚ'XÍNG"), "lv'xing")
    }

    func testLexiconConsumptionMatchesTraditionalSurfaceAfterSimplifiedNormalization() throws {
        let url = try writeTemporaryDictionary(
            """
            # Rime dictionary
            # encoding: utf-8

            ---
            name: test
            version: "0.1"
            sort: by_weight
            ...

            中国\tzhong guo\t200
            输入法\tshu ru fa\t180
            """
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let tokenizer = try PinyinTokenizer.fromDictionaryFile(at: url)
        let lexicon = try RimeLexicon.fromDictionaryFiles(at: [url])

        XCTAssertEqual(
            lexicon.consumption(
                forSurface: "中國", rawInput: "zhongguo", comment: nil, tokenizer: tokenizer),
            RimeConsumption(tokenCount: 2, tokens: ["zhong", "guo"])
        )
        XCTAssertEqual(
            lexicon.consumption(
                forSurface: "輸入法", rawInput: "shurufa", comment: nil, tokenizer: tokenizer),
            RimeConsumption(tokenCount: 3, tokens: ["shu", "ru", "fa"])
        )
    }
}
