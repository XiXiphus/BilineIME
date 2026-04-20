import BilineCore
import BilineTestSupport
import XCTest

final class FixtureCandidateEngineTests: XCTestCase {
    func testWholePhraseCandidateAppearsForCombinedInput() {
        let session = DemoFixtures.makeSession(pageSize: 5)

        let snapshot = session.updateInput("nihao")

        XCTAssertEqual(snapshot.rawInput, "nihao")
        XCTAssertEqual(snapshot.markedText, "你好")
        XCTAssertEqual(snapshot.candidates.first?.surface, "你好")
        XCTAssertEqual(snapshot.pageIndex, 0)
        XCTAssertTrue(snapshot.isComposing)
    }

    func testSelectionMovesAcrossPages() {
        let session = DemoFixtures.makeSession(pageSize: 2)

        _ = session.updateInput("shi")
        _ = session.moveSelection(.next)
        let snapshot = session.moveSelection(.next)

        XCTAssertEqual(snapshot.pageIndex, 1)
        XCTAssertEqual(snapshot.selectedIndex, 0)
        XCTAssertEqual(snapshot.candidates.first?.surface, "事")
    }

    func testTurnPageMovesToNextChunk() {
        let session = DemoFixtures.makeSession(pageSize: 2)

        _ = session.updateInput("shi")
        let snapshot = session.turnPage(.next)

        XCTAssertEqual(snapshot.pageIndex, 1)
        XCTAssertEqual(snapshot.candidates.map(\.surface), ["事", "市"])
    }

    func testTurnPageCanMoveBackToPreviousChunk() {
        let session = DemoFixtures.makeSession(pageSize: 2)

        _ = session.updateInput("shi")
        _ = session.turnPage(.next)
        let snapshot = session.turnPage(.previous)

        XCTAssertEqual(snapshot.pageIndex, 0)
        XCTAssertEqual(snapshot.candidates.map(\.surface), ["是", "时"])
    }

    func testCommitResetsCompositionState() {
        let session = DemoFixtures.makeSession(pageSize: 5)

        _ = session.updateInput("nihao")
        let result = session.commitSelected()

        XCTAssertEqual(result.committedText, "你好")
        XCTAssertEqual(result.snapshot, .idle)
    }

    func testUnknownInputKeepsMarkedTextButNoCandidates() {
        let session = DemoFixtures.makeSession(pageSize: 5)

        let snapshot = session.updateInput("xyz")

        XCTAssertEqual(snapshot.rawInput, "xyz")
        XCTAssertEqual(snapshot.markedText, "xyz")
        XCTAssertTrue(snapshot.candidates.isEmpty)
        XCTAssertTrue(snapshot.isComposing)
    }

    func testLongestLeftPrefixProducesCandidatesAndRemainingTail() {
        let session = DemoFixtures.makeSession(pageSize: 5)

        let snapshot = session.updateInput("haopingguo")

        XCTAssertEqual(snapshot.rawInput, "haopingguo")
        XCTAssertEqual(snapshot.activeRawInput, "haopingguo")
        XCTAssertEqual(snapshot.remainingRawInput, "")
        XCTAssertEqual(snapshot.consumedTokenCount, 3)
        XCTAssertEqual(snapshot.candidates.first?.surface, "好苹果")
        XCTAssertTrue(snapshot.candidates.contains(where: { $0.surface == "好" && $0.consumedTokenCount == 1 }))
        XCTAssertTrue(snapshot.isComposing)
    }
}
