import BilineCore
import XCTest

@testable import BilineRime

final class PinyinDictionaryEngineTests: XCTestCase {
    func testTokenizerNormalizesToneMarksAndUmlaut() throws {
        let tokenizer = PinyinTokenizer(syllables: [])

        XCTAssertEqual(tokenizer.tokenize("lǜe") ?? [], ["lve"])
        XCTAssertEqual(tokenizer.tokenize("xi'an") ?? [], ["xi", "an"])
        XCTAssertEqual(tokenizer.readingTokens(from: "nǚ peng you") ?? [], ["nv", "peng", "you"])
    }

    func testFallbackDictionaryRanksModernFullPhraseAheadOfPrefix() throws {
        let factory = try DictionaryPinyinCandidateEngineFactory(characterForm: .simplified)
        let session = factory.makeSession(config: EngineConfig(pageSize: 25))

        let snapshot = session.updateInput("pinyinshurufa")

        XCTAssertFalse(snapshot.candidates.isEmpty)
        XCTAssertEqual(snapshot.candidates.first?.surface, "拼音输入法")
        XCTAssertEqual(snapshot.activeRawInput, "pinyinshurufa")
        XCTAssertEqual(snapshot.remainingRawInput, "")
        XCTAssertEqual(snapshot.consumedTokenCount, 5)
    }

    func testFallbackDictionaryPrefixCommitLeavesTail() throws {
        let factory = try DictionaryPinyinCandidateEngineFactory(characterForm: .simplified)
        let session = factory.makeSession(config: EngineConfig(pageSize: 25))

        var snapshot = session.updateInput("haopingguo")
        guard let targetIndex = snapshot.candidates.firstIndex(where: { $0.surface == "好" }) else {
            XCTFail("Expected 好 to be available as a prefix candidate.")
            return
        }

        while snapshot.selectedIndex < targetIndex {
            snapshot = session.moveSelection(.next)
        }

        let result = session.commitSelected()
        XCTAssertEqual(result.committedText, "好")
        XCTAssertEqual(result.snapshot.rawInput, "pingguo")
        XCTAssertEqual(result.snapshot.remainingRawInput, "")
    }

    func testFallbackDictionaryTurnPageNextAtSinglePageBoundaryPreservesSelection() throws {
        let factory = try DictionaryPinyinCandidateEngineFactory(characterForm: .simplified)
        let session = factory.makeSession(config: EngineConfig(pageSize: 1_000))

        _ = session.updateInput("shi")
        let before = session.moveSelection(.next)
        XCTAssertGreaterThan(before.selectedIndex, 0)

        let after = session.turnPage(.next)

        XCTAssertEqual(after.pageIndex, before.pageIndex)
        XCTAssertEqual(after.selectedIndex, before.selectedIndex)
        XCTAssertEqual(after.candidates, before.candidates)
    }

    func testFallbackDictionaryTurnPagePreviousAtFirstPageBoundaryPreservesSelection() throws {
        let factory = try DictionaryPinyinCandidateEngineFactory(characterForm: .simplified)
        let session = factory.makeSession(config: EngineConfig(pageSize: 1_000))

        _ = session.updateInput("shi")
        let before = session.moveSelection(.next)
        XCTAssertGreaterThan(before.selectedIndex, 0)

        let after = session.turnPage(.previous)

        XCTAssertEqual(after.pageIndex, before.pageIndex)
        XCTAssertEqual(after.selectedIndex, before.selectedIndex)
        XCTAssertEqual(after.candidates, before.candidates)
    }
}
