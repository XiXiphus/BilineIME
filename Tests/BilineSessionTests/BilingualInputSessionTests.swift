import BilineSession
import BilineTestSupport
import XCTest

final class BilingualInputSessionTests: XCTestCase {
    func testShiftToggleChangesLayerWithoutChangingCell() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "nihao")
        let before = session.snapshot

        session.toggleActiveLayer()
        let after = session.snapshot

        XCTAssertEqual(before.selectedRow, after.selectedRow)
        XCTAssertEqual(before.selectedColumn, after.selectedColumn)
        XCTAssertEqual(before.selectedFlatIndex, after.selectedFlatIndex)
        XCTAssertEqual(after.activeLayer, .english)
    }

    func testMovingColumnKeepsEnglishLayerActive() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.toggleActiveLayer()
        session.moveColumn(.next)

        XCTAssertEqual(session.snapshot.activeLayer, .english)
        XCTAssertEqual(session.snapshot.selectedRow, 0)
        XCTAssertEqual(session.snapshot.selectedColumn, 1)
        XCTAssertEqual(session.snapshot.selectedFlatIndex, 1)
    }

    func testCompactPresentationDoesNotPadCandidatesToFiveColumns() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "ni")

        XCTAssertEqual(session.snapshot.presentationMode, .compact)
        XCTAssertEqual(session.snapshot.items.count, 3)
        XCTAssertEqual(session.snapshot.visibleRowCount, 1)
        XCTAssertEqual(session.snapshot.items(inRow: 0).map(\.candidate.surface), ["你", "呢", "妮"])
        XCTAssertNil(session.snapshot.item(row: 0, column: 3))
    }

    func testExpandedNavigationMovesByRowsAndColumns() {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 2,
            expandedRowCount: 2
        )

        session.append(text: "shi")
        session.expandAndAdvanceRow()
        session.moveColumn(.next)

        XCTAssertEqual(session.snapshot.presentationMode, .expanded)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.selectedColumn, 1)
        XCTAssertEqual(session.snapshot.selectedFlatIndex, 3)
        XCTAssertEqual(session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "市")
    }

    func testMoveRowAdvancesToNextPageWhenReachingBottomRow() {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 2,
            expandedRowCount: 2
        )

        session.append(text: "shi")
        session.expandAndAdvanceRow()
        session.moveColumn(.next)
        session.browseNextRow()

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.presentationMode, .expanded)
        XCTAssertEqual(session.snapshot.selectedRow, 0)
        XCTAssertEqual(session.snapshot.selectedColumn, 1)
        XCTAssertEqual(session.snapshot.selectedFlatIndex, 1)
        XCTAssertEqual(session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "识")
    }

    func testFirstRowHyphenCollapsesAndResetsToFirstColumn() {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 2,
            expandedRowCount: 2
        )

        session.append(text: "shi")
        session.expandAndAdvanceRow()
        session.browsePreviousRow()
        session.moveColumn(.next)

        XCTAssertEqual(session.snapshot.presentationMode, .expanded)
        XCTAssertEqual(session.snapshot.selectedRow, 0)
        XCTAssertEqual(session.snapshot.selectedColumn, 1)

        session.collapseToCompactAndSelectFirst()

        XCTAssertEqual(session.snapshot.presentationMode, .compact)
        XCTAssertEqual(session.snapshot.selectedRow, 0)
        XCTAssertEqual(session.snapshot.selectedColumn, 0)
        XCTAssertEqual(session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "是")
    }

    func testEqualAfterCollapseExpandsFromFirstColumnToNextRow() {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 2,
            expandedRowCount: 2
        )

        session.append(text: "shi")
        session.expandAndAdvanceRow()
        session.browsePreviousRow()
        session.moveColumn(.next)
        session.collapseToCompactAndSelectFirst()

        session.expandAndAdvanceRow()

        XCTAssertEqual(session.snapshot.presentationMode, .expanded)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.selectedColumn, 0)
        XCTAssertEqual(session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "事")
    }

    func testExpandAndAdvanceShowsSecondRowWhenPageHasMoreThanFiveCandidates() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        XCTAssertEqual(session.snapshot.items.count, 10)
        XCTAssertEqual(session.snapshot.presentationMode, .compact)
        XCTAssertEqual(session.snapshot.visibleRowCount, 1)

        session.expandAndAdvanceRow()

        XCTAssertEqual(session.snapshot.presentationMode, .expanded)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.items(inRow: 1).map(\.candidate.surface), ["识", "诗", "十", "史", "食"])
    }

    func testTurnPagePreservesSelectedRowAndColumnWhenPossible() {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 2,
            expandedRowCount: 2
        )

        session.append(text: "shi")
        session.expandAndAdvanceRow()
        session.moveColumn(.next)

        session.turnPage(.next)

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.selectedColumn, 1)
        XCTAssertEqual(session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "十")
    }

    func testAppendLiteralSwitchesToRawBufferOnlyComposition() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.appendLiteral(text: "-")

        XCTAssertTrue(session.snapshot.isComposing)
        XCTAssertEqual(session.snapshot.rawInput, "shi-")
        XCTAssertEqual(session.snapshot.markedText, "shi-")
        XCTAssertTrue(session.snapshot.items.isEmpty)
        XCTAssertEqual(session.snapshot.presentationMode, .compact)
    }

    func testDeletingLiteralBufferRestoresCandidateComposition() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.appendLiteral(text: "-")
        session.deleteBackward()

        XCTAssertTrue(session.snapshot.isComposing)
        XCTAssertEqual(session.snapshot.rawInput, "shi")
        XCTAssertFalse(session.snapshot.items.isEmpty)
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "是")
    }

    func testCommitSelectionCommitsRawBufferWhenNoCandidatesExist() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.appendLiteral(text: "-")
        session.appendLiteral(text: "-")

        XCTAssertEqual(session.commitSelection(), "shi--")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testVisiblePreviewUpdatesToReadyWithoutExtraNavigation() async {
        let session = DemoFixtures.makeBilingualSession()
        let ready = expectation(description: "visible preview ready")
        var didFulfill = false

        session.onSnapshotUpdate = { snapshot in
            guard !didFulfill else { return }
            guard snapshot.presentationMode == .compact,
                snapshot.visibleRowCount == 1,
                snapshot.items.first?.candidate.surface == "是",
                snapshot.items.first?.englishText == "is"
            else {
                return
            }
            didFulfill = true
            ready.fulfill()
        }

        session.append(text: "shi")

        await fulfillment(of: [ready], timeout: 1.0)
    }

    func testCommitChineseSelectionIgnoresEnglishLayer() async {
        let session = DemoFixtures.makeBilingualSession()
        let ready = expectation(description: "english preview ready for selected candidate")
        var didFulfill = false

        session.onSnapshotUpdate = { snapshot in
            guard !didFulfill else { return }
            guard snapshot.items.first?.englishText == "is" else {
                return
            }
            didFulfill = true
            ready.fulfill()
        }

        session.append(text: "shi")
        session.toggleActiveLayer()

        await fulfillment(of: [ready], timeout: 1.0)

        XCTAssertEqual(session.snapshot.activeLayer, .english)
        XCTAssertEqual(session.commitChineseSelection(), "是")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testEnglishCommitUsesReadyPreviewText() async {
        let session = DemoFixtures.makeBilingualSession()
        let ready = expectation(description: "english preview ready")
        var didFulfill = false

        session.onSnapshotUpdate = { snapshot in
            guard !didFulfill else { return }
            guard snapshot.activeLayer == .english,
                snapshot.selectedFlatIndex == 0,
                snapshot.items.first?.englishText == "hello"
            else {
                return
            }
            didFulfill = true
            ready.fulfill()
        }

        session.append(text: "nihao")
        session.toggleActiveLayer()

        await fulfillment(of: [ready], timeout: 1.0)

        XCTAssertEqual(session.commitSelection(), "hello")
        XCTAssertEqual(session.snapshot.activeLayer, .chinese)
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testEnglishCommitStaysBlockedWhilePreviewIsLoading() {
        let session = DemoFixtures.makeBilingualSession(delay: .milliseconds(60))

        session.append(text: "nihao")
        session.toggleActiveLayer()

        XCTAssertNil(session.commitSelection())
        XCTAssertTrue(session.snapshot.isComposing)
        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testSwitchingPagesLoadsVisibleCandidatesWithoutCorruptingNewPage() async {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 2,
            expandedRowCount: 1,
            delay: .milliseconds(40)
        )
        let pageTwo = expectation(description: "page two english preview ready")
        var didFulfill = false

        session.onSnapshotUpdate = { snapshot in
            guard !didFulfill else { return }
            guard snapshot.pageIndex == 1,
                snapshot.items.first?.candidate.surface == "事",
                snapshot.items.first?.englishText == "matter"
            else {
                return
            }
            didFulfill = true
            pageTwo.fulfill()
        }

        session.append(text: "shi")
        session.turnPage(.next)

        await fulfillment(of: [pageTwo], timeout: 1.0)

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.items.map(\.candidate.surface), ["事", "市"])
        XCTAssertEqual(session.snapshot.items.first?.englishText, "matter")
        session.cancel()
    }
}
