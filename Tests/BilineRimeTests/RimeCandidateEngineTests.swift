import BilineCore
import BilinePreview
import XCTest

@testable import BilineRime

final class RimeCandidateEngineTests: XCTestCase {
    private let runtimeLibraryPath = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Caches/BilineIME/RimeVendor/1.16.1/lib/librime.1.dylib")

    private func makeSession(characterForm: CharacterForm = .simplified) throws
        -> any CandidateEngineSession
    {
        guard FileManager.default.fileExists(atPath: runtimeLibraryPath.path) else {
            throw XCTSkip("librime runtime has not been built yet.")
        }
        let factory = try RimeCandidateEngineFactory(
            fuzzyPinyinEnabled: false,
            characterForm: characterForm
        )
        return factory.makeSession(config: EngineConfig(pageSize: 25))
    }

    func testPhraseCandidateRanksAheadOfShortPrefix() throws {
        let session = try makeSession()
        let snapshot = session.updateInput("haopingguo")

        XCTAssertFalse(snapshot.candidates.isEmpty)
        XCTAssertEqual(snapshot.candidates.first?.surface, "好苹果")
        XCTAssertEqual(snapshot.remainingRawInput, "")
        XCTAssertEqual(snapshot.consumedTokenCount, 3)
    }

    func testSelectingPrefixCandidateLeavesTailAfterCommit() throws {
        let session = try makeSession()
        _ = session.updateInput("haopingguo")

        var current = session.updateInput("haopingguo")
        guard let targetIndex = current.candidates.firstIndex(where: { $0.surface == "好" }) else {
            XCTFail("Expected prefix candidate 好 to exist.")
            return
        }

        while current.selectedIndex < targetIndex {
            current = session.moveSelection(.next)
        }

        let result = session.commitSelected()
        XCTAssertEqual(result.committedText, "好")
        XCTAssertEqual(result.snapshot.rawInput, "pingguo")
        XCTAssertEqual(result.snapshot.remainingRawInput, "")
    }

    func testCommittingWholePhraseEndsComposition() throws {
        let session = try makeSession()
        _ = session.updateInput("nihao")

        let result = session.commitSelected()

        XCTAssertEqual(result.committedText, "你好")
        XCTAssertEqual(result.snapshot, .idle)
    }

    func testCommittingZhegeaChoiceEndsComposition() throws {
        let session = try makeSession()
        _ = session.updateInput("zhegea")

        let result = session.commitSelected()

        XCTAssertFalse(result.committedText.isEmpty)
        XCTAssertEqual(result.snapshot, .idle)
    }

    func testCommittingTraditionalSurfacePhraseEndsComposition() throws {
        let session = try makeSession()
        _ = session.updateInput("zhongguo")

        let result = session.commitSelected()

        XCTAssertEqual(result.committedText, "中国")
        XCTAssertEqual(result.snapshot, .idle)
    }

    func testTraditionalModeConvertsSimplifiedDictionaryOutput() throws {
        let session = try makeSession(characterForm: .traditional)
        _ = session.updateInput("zhongguo")

        let result = session.commitSelected()

        XCTAssertEqual(result.committedText, "中國")
        XCTAssertEqual(result.snapshot, .idle)
    }

    func testRimeIceRanksModernSimplifiedPhrases() throws {
        let session = try makeSession()

        let shuangyu = session.updateInput("shuangyu")
        XCTAssertEqual(shuangyu.candidates.first?.surface, "双语")
        XCTAssertFalse(shuangyu.candidates.prefix(5).contains(where: { $0.surface == "雙魚" }))

        let jianti = session.updateInput("jiantizhongwen")
        XCTAssertEqual(jianti.candidates.first?.surface, "简体中文")
    }

    func testTraditionalModeUsesTraditionalSchemaOutput() throws {
        let session = try makeSession(characterForm: .traditional)
        _ = session.updateInput("shuangyu")

        let result = session.commitSelected()

        XCTAssertEqual(result.committedText, "雙語")
        XCTAssertEqual(result.snapshot, .idle)
    }
}
