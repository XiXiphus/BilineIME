import BilineCore
import BilinePreview
import BilineSession
import BilineTestSupport
import XCTest

final class BilingualInputSessionTests: XCTestCase {
    func testActiveLayerChangesKeepSelectionAndPersistAcrossTypingAndBrowsing() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.moveColumn(.next)
        let before = session.snapshot

        session.setActiveLayer(.english)

        XCTAssertEqual(session.snapshot.selectedRow, before.selectedRow)
        XCTAssertEqual(session.snapshot.selectedColumn, before.selectedColumn)
        XCTAssertEqual(session.snapshot.selectedFlatIndex, before.selectedFlatIndex)
        XCTAssertEqual(session.snapshot.activeLayer, .english)

        session.append(text: "a")
        session.browseNextRow()

        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testCommitRawInputCommitsPinyinBeforeExplicitCandidateSelection() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "nihao")

        XCTAssertEqual(session.commitRawInput(), "nihao")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testMovingColumnMarksSelectionExplicitForReturnSemantics() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        XCTAssertFalse(session.hasExplicitCandidateSelection)

        session.moveColumn(.next)

        XCTAssertTrue(session.hasExplicitCandidateSelection)
        XCTAssertEqual(session.commitSelection(), "时")
    }

    func testRawCursorMovesByPinyinBlockAndInsertsAtCursor() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "nihao")
        XCTAssertEqual(session.snapshot.rawCursorIndex, 5)
        XCTAssertEqual(session.snapshot.markedSelectionRange.location, 6)

        session.moveRawCursorByBlock(.previous)

        XCTAssertEqual(session.snapshot.rawCursorIndex, 2)
        XCTAssertEqual(session.snapshot.markedSelectionRange.location, 2)

        session.append(text: "men")

        XCTAssertEqual(session.snapshot.rawInput, "nimenhao")
        XCTAssertEqual(session.snapshot.rawCursorIndex, 5)
        XCTAssertEqual(session.snapshot.markedSelectionRange.location, 6)
    }

    func testRawCursorMovesByCharacterForPlainArrowSemantics() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "nihao")
        session.moveRawCursorByBlock(.previous)
        session.moveRawCursorByCharacter(.previous)

        XCTAssertEqual(session.snapshot.rawCursorIndex, 1)
        XCTAssertEqual(session.snapshot.markedSelectionRange.location, 1)

        session.moveRawCursorByCharacter(.next)

        XCTAssertEqual(session.snapshot.rawCursorIndex, 2)
        XCTAssertEqual(session.snapshot.markedSelectionRange.location, 2)
    }

    func testRawCursorMarkedSelectionUsesRenderedPunctuationPrefix() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.appendLiteral(text: "%")
        session.appendLiteral(text: "_")
        session.appendLiteral(text: "+")
        session.moveRawCursorByBlock(.previous)

        XCTAssertEqual(session.snapshot.displayRawInput, "shi％＿＋")
        XCTAssertEqual(session.snapshot.rawCursorIndex, 5)
        XCTAssertEqual(session.snapshot.markedSelectionRange.location, 5)
    }

    func testRawCursorMovesToEdgesAndBackspaceAtStartDeletesFromEnd() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "nihao")
        session.moveRawCursorToStart()

        XCTAssertEqual(session.snapshot.rawCursorIndex, 0)
        XCTAssertEqual(session.snapshot.markedSelectionRange.location, 0)

        session.deleteBackward()

        XCTAssertEqual(session.snapshot.rawInput, "niha")
        XCTAssertEqual(session.snapshot.rawCursorIndex, 4)

        session.moveRawCursorToEnd()
        session.deleteBackward()

        XCTAssertEqual(session.snapshot.rawInput, "nih")
        XCTAssertEqual(session.snapshot.rawCursorIndex, 3)
    }

    func testOptionBackspaceDeletesPreviousPinyinBlock() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "haopingguo")
        session.deleteRawBackwardByBlock()

        XCTAssertEqual(session.snapshot.rawInput, "haoping")
        XCTAssertEqual(session.snapshot.rawCursorIndex, 7)

        session.moveRawCursorByBlock(.previous)
        XCTAssertEqual(session.snapshot.rawInput, "haoping")
        XCTAssertEqual(session.snapshot.rawCursorIndex, 3)

        session.deleteRawBackwardByBlock()

        XCTAssertEqual(session.snapshot.rawInput, "ping")
        XCTAssertEqual(session.snapshot.rawCursorIndex, 0)

        session.deleteRawBackwardByBlock()

        XCTAssertEqual(session.snapshot, .idle)
    }

    func testCommandBackspaceDeletesToRawCursorStart() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "haopingguo")
        session.moveRawCursorByBlock(.previous)
        session.deleteRawToStart()

        XCTAssertEqual(session.snapshot.rawInput, "guo")
        XCTAssertEqual(session.snapshot.rawCursorIndex, 0)
        XCTAssertEqual(session.snapshot.markedSelectionRange.location, 0)
    }

    func testRawEditingClearsExplicitCandidateSelection() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.moveColumn(.next)
        XCTAssertTrue(session.hasExplicitCandidateSelection)

        session.deleteRawBackwardByBlock()

        XCTAssertFalse(session.hasExplicitCandidateSelection)
        XCTAssertFalse(session.hasEverExpandedInCurrentComposition)
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
        XCTAssertEqual(
            session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "市")
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
        XCTAssertEqual(
            session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "识")
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
        XCTAssertEqual(
            session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "是")
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
        XCTAssertEqual(
            session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "事")
    }

    func testExpandAndAdvanceShowsSecondRowWhenPageHasMoreThanFiveCandidates() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        XCTAssertEqual(session.snapshot.items.count, 10)
        XCTAssertEqual(session.snapshot.presentationMode, .compact)
        XCTAssertEqual(session.compositionMode, .candidateCompact)
        XCTAssertFalse(session.hasEverExpandedInCurrentComposition)
        XCTAssertEqual(session.snapshot.visibleRowCount, 1)

        session.expandAndAdvanceRow()

        XCTAssertEqual(session.snapshot.presentationMode, .expanded)
        XCTAssertEqual(session.compositionMode, .candidateExpanded)
        XCTAssertTrue(session.hasEverExpandedInCurrentComposition)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(
            session.snapshot.items(inRow: 1).map(\.candidate.surface), ["识", "诗", "十", "史", "食"])
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
        XCTAssertEqual(
            session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "十")
    }

    func testBrowsePreviousRowFromFirstRowOnLaterPageTurnsToPreviousPage() {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 2,
            expandedRowCount: 2
        )

        session.append(text: "shi")
        session.expandAndAdvanceRow()
        session.browseNextRow()

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.selectedRow, 0)

        session.browsePreviousRow()

        XCTAssertEqual(session.snapshot.pageIndex, 0)
        XCTAssertEqual(session.snapshot.presentationMode, .expanded)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.selectedColumn, 0)
        XCTAssertEqual(
            session.snapshot.items[session.snapshot.selectedFlatIndex].candidate.surface, "事")
    }

    func testExpandedRowBrowsingKeepsPreferredColumnAcrossShortLastPageBoundary() {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 3,
            expandedRowCount: 2
        )

        session.append(text: "shi")
        session.selectColumn(at: 2)
        session.expandAndAdvanceRow()

        XCTAssertEqual(session.snapshot.pageIndex, 0)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.selectedColumn, 2)

        session.browseNextRow()

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.selectedRow, 0)
        XCTAssertEqual(session.snapshot.selectedColumn, 2)

        session.browseNextRow()

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.items.count, 4)
        XCTAssertEqual(session.snapshot.items(inRow: 1).count, 1)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.selectedColumn, 0)

        let boundarySnapshot = session.snapshot
        session.browseNextRow()
        session.browseNextRow()

        XCTAssertEqual(session.snapshot.pageIndex, boundarySnapshot.pageIndex)
        XCTAssertEqual(session.snapshot.selectedRow, boundarySnapshot.selectedRow)
        XCTAssertEqual(session.snapshot.selectedColumn, boundarySnapshot.selectedColumn)
        XCTAssertEqual(session.snapshot.selectedFlatIndex, boundarySnapshot.selectedFlatIndex)

        session.browsePreviousRow()

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.selectedRow, 0)
        XCTAssertEqual(session.snapshot.selectedColumn, 2)
        XCTAssertEqual(session.snapshot.selectedFlatIndex, 2)
    }

    func testHorizontalMoveAfterShortRowClampReanchorsPreferredColumn() {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 4,
            expandedRowCount: 2
        )

        session.append(text: "shi")
        session.selectColumn(at: 3)
        session.expandAndAdvanceRow()

        XCTAssertEqual(session.snapshot.pageIndex, 0)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.selectedColumn, 3)

        session.browseNextRow()

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.items.count, 2)
        XCTAssertEqual(session.snapshot.selectedRow, 0)
        XCTAssertEqual(session.snapshot.selectedColumn, 1)

        session.moveColumn(.previous)

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.selectedRow, 0)
        XCTAssertEqual(session.snapshot.selectedColumn, 0)

        session.browsePreviousRow()

        XCTAssertEqual(session.snapshot.pageIndex, 0)
        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.selectedColumn, 0)
    }

    func testRawBufferOnlyLiteralsAccumulateAndUseChinesePunctuationPolicy() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.appendLiteral(text: "-")
        session.appendLiteral(text: "=")
        session.appendLiteral(text: "%")
        session.appendLiteral(text: "+")

        XCTAssertTrue(session.snapshot.isComposing)
        XCTAssertEqual(session.compositionMode, .rawBufferOnly)
        XCTAssertEqual(session.snapshot.rawInput, "shi-=%+")
        XCTAssertEqual(session.snapshot.displayRawInput, "shi－＝％＋")
        XCTAssertEqual(session.snapshot.markedText, "shi－＝％＋")
        XCTAssertTrue(session.snapshot.items.isEmpty)
        XCTAssertEqual(session.snapshot.presentationMode, .compact)
    }

    func testExpandHistoryPreventsHyphenFromReenteringRawBufferOnly() {
        let session = DemoFixtures.makeBilingualSession(
            compactColumnCount: 2,
            expandedRowCount: 2
        )

        session.append(text: "shi")
        session.expandAndAdvanceRow()
        session.collapseToCompactAndSelectFirst()

        XCTAssertTrue(session.hasEverExpandedInCurrentComposition)
        XCTAssertEqual(session.compositionMode, .candidateCompact)

        session.collapseToCompactAndSelectFirst()

        XCTAssertEqual(session.compositionMode, .candidateCompact)
        XCTAssertFalse(session.snapshot.items.isEmpty)
        XCTAssertEqual(session.snapshot.rawInput, "shi")
    }

    func testTrailingUppercaseLatinStaysInCandidateComposition() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.appendLiteral(text: "A")
        session.appendLiteral(text: "A")

        XCTAssertEqual(session.compositionMode, .candidateCompact)
        XCTAssertEqual(session.snapshot.rawInput, "shiAA")
        XCTAssertEqual(session.snapshot.markedText, "shi AA")
        XCTAssertFalse(session.snapshot.items.isEmpty)
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "是AA")
        XCTAssertEqual(session.commitSelection(), "是AA")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testTrailingUppercaseLatinDoesNotAttachToShortPrefixCandidate() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "haopingguo")
        session.appendLiteral(text: "A")

        XCTAssertEqual(session.snapshot.rawInput, "haopingguoA")
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "好苹果A")
        XCTAssertTrue(session.snapshot.items.contains(where: { $0.candidate.surface == "好" }))

        session.moveColumn(.next)

        XCTAssertEqual(session.snapshot.items[1].candidate.surface, "好")
        XCTAssertEqual(session.commitSelection(), "好")
        XCTAssertEqual(session.snapshot.rawInput, "pingguoA")
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "苹果A")
    }

    func testPinyinAfterUppercaseLatinStaysInCandidateComposition() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.appendLiteral(text: "A")
        session.appendLiteral(text: "B")
        session.appendLiteral(text: "C")
        session.append(text: "shi")

        XCTAssertEqual(session.compositionMode, .candidateCompact)
        XCTAssertEqual(session.snapshot.rawInput, "shiABCshi")
        XCTAssertEqual(session.snapshot.markedText, "shi ABC shi")
        XCTAssertFalse(session.snapshot.items.isEmpty)
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "是ABC是")
        XCTAssertEqual(session.commitSelection(), "是ABC是")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testRawCursorDeletionInsideUppercaseLatinMixedCompositionKeepsCandidateMode() {
        let blockDeleteSession = DemoFixtures.makeBilingualSession()

        blockDeleteSession.append(text: "shi")
        blockDeleteSession.appendLiteral(text: "A")
        blockDeleteSession.appendLiteral(text: "B")
        blockDeleteSession.appendLiteral(text: "C")
        blockDeleteSession.append(text: "shi")
        blockDeleteSession.moveRawCursorByBlock(.previous)

        XCTAssertEqual(blockDeleteSession.snapshot.rawCursorIndex, 6)

        blockDeleteSession.deleteRawBackwardByBlock()

        XCTAssertEqual(blockDeleteSession.compositionMode, .candidateCompact)
        XCTAssertEqual(blockDeleteSession.snapshot.rawInput, "shiABshi")
        XCTAssertEqual(blockDeleteSession.snapshot.markedText, "shi AB shi")
        XCTAssertEqual(blockDeleteSession.snapshot.items.first?.candidate.surface, "是AB是")

        let deleteToStartSession = DemoFixtures.makeBilingualSession()

        deleteToStartSession.append(text: "shi")
        deleteToStartSession.appendLiteral(text: "A")
        deleteToStartSession.appendLiteral(text: "B")
        deleteToStartSession.appendLiteral(text: "C")
        deleteToStartSession.append(text: "shi")
        deleteToStartSession.moveRawCursorByBlock(.previous)

        XCTAssertEqual(deleteToStartSession.snapshot.rawCursorIndex, 6)

        deleteToStartSession.deleteRawToStart()

        XCTAssertEqual(deleteToStartSession.compositionMode, .candidateCompact)
        XCTAssertEqual(deleteToStartSession.snapshot.rawInput, "shi")
        XCTAssertEqual(deleteToStartSession.snapshot.rawCursorIndex, 0)
        XCTAssertEqual(deleteToStartSession.snapshot.markedText, "shi")
        XCTAssertEqual(deleteToStartSession.snapshot.items.first?.candidate.surface, "是")
    }

    func testUppercaseLatinSegmentKeepsFollowingPinyinChunkInCandidateComposition() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "haopingguo")
        session.appendLiteral(text: "A")
        session.appendLiteral(text: "B")
        session.appendLiteral(text: "C")
        session.append(text: "haopingguo")

        XCTAssertEqual(session.compositionMode, .candidateCompact)
        XCTAssertEqual(session.snapshot.rawInput, "haopingguoABChaopingguo")
        XCTAssertEqual(session.snapshot.markedText, "hao ping guo ABC hao ping guo")
        XCTAssertFalse(session.snapshot.items.isEmpty)
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "好苹果ABC好苹果")
        XCTAssertEqual(session.commitSelection(), "好苹果ABC好苹果")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testAbbreviatedPinyinBeforeUppercaseLatinStaysInCandidateComposition() {
        let session = makeSessionWithEngine(
            snapshotsByInput: [
                "hpg": abbreviatedHpgSnapshot()
            ],
            commitResult: CommitResult(committedText: "好苹果", snapshot: .idle)
        )

        session.append(text: "hpg")
        session.appendLiteral(text: "A")
        session.appendLiteral(text: "B")
        session.appendLiteral(text: "C")
        session.append(text: "hpg")

        XCTAssertEqual(session.compositionMode, .candidateCompact)
        XCTAssertEqual(session.snapshot.rawInput, "hpgABChpg")
        XCTAssertEqual(session.snapshot.markedText, "h p g ABC h p g")
        XCTAssertFalse(session.snapshot.items.isEmpty)
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "好苹果ABC好苹果")
        XCTAssertEqual(session.commitSelection(), "好苹果ABC好苹果")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testAbbreviatedPinyinPrefixCommitKeepsMixedTail() {
        let session = makeSessionWithEngine(
            snapshotsByInput: [
                "hpg": abbreviatedHpgSnapshot(selectedIndex: 1),
                "pg": abbreviatedPgSnapshot(),
            ],
            commitResult: CommitResult(committedText: "好", snapshot: .idle)
        )

        session.append(text: "hpg")
        session.appendLiteral(text: "A")
        session.appendLiteral(text: "B")
        session.appendLiteral(text: "C")
        session.append(text: "hpg")

        XCTAssertEqual(session.snapshot.rawInput, "hpgABChpg")
        XCTAssertEqual(session.snapshot.markedText, "h p g ABC h p g")
        XCTAssertEqual(session.snapshot.items[1].candidate.surface, "好")

        XCTAssertEqual(session.commitSelection(), "好")
        XCTAssertEqual(session.snapshot.rawInput, "pgABChpg")
        XCTAssertEqual(session.snapshot.markedText, "p g ABC h p g")
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "苹果ABC好苹果")
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

        XCTAssertEqual(session.commitSelection(), "shi－－")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testCommitSelectionTransformsRawBufferPunctuationForCommit() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "ni")
        session.appendLiteral(text: "-")
        session.appendLiteral(text: "=")
        session.appendLiteral(text: "%")
        session.appendLiteral(text: "+")

        XCTAssertEqual(session.commitSelection(), "ni－＝％＋")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testRenderCommittedTextUsesChinesePunctuationPolicy() {
        let session = DemoFixtures.makeBilingualSession()

        XCTAssertEqual(session.renderCommittedText(","), "，")
        XCTAssertEqual(session.renderCommittedText("()"), "（）")
        XCTAssertEqual(session.renderCommittedText("%+_"), "％＋＿")
    }

    func testHalfwidthPunctuationPolicyKeepsASCIIPunctuation() {
        let session = DemoFixtures.makeBilingualSession(punctuationForm: .halfwidth)

        session.append(text: "shi")
        session.appendLiteral(text: "%")
        session.appendLiteral(text: "_")
        session.appendLiteral(text: "+")

        XCTAssertEqual(session.snapshot.displayRawInput, "shi%_+")
        XCTAssertEqual(session.commitSelection(), "shi%_+")
        XCTAssertEqual(session.renderCommittedText(","), ",")
        XCTAssertEqual(session.renderCommittedText("()"), "()")
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
        session.setActiveLayer(.english)

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
        session.setActiveLayer(.english)

        await fulfillment(of: [ready], timeout: 1.0)

        XCTAssertEqual(session.commitSelection(), "hello")
        XCTAssertEqual(session.snapshot.activeLayer, .chinese)
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testEnglishCommitStaysBlockedWhilePreviewIsLoading() {
        let session = DemoFixtures.makeBilingualSession(delay: .milliseconds(60))

        session.append(text: "nihao")
        session.setActiveLayer(.english)

        XCTAssertNil(session.commitSelection())
        XCTAssertTrue(session.snapshot.isComposing)
        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testPurePinyinModeHidesEnglishLayerAndCommitsChinese() {
        let session = DemoFixtures.makeBilingualSession(bilingualModeEnabled: false)

        session.append(text: "shi")

        XCTAssertFalse(session.snapshot.showsEnglishCandidates)
        XCTAssertEqual(session.snapshot.activeLayer, .chinese)
        XCTAssertTrue(session.snapshot.items.allSatisfy { $0.previewState == .unavailable })

        session.setActiveLayer(.english)

        XCTAssertEqual(session.snapshot.activeLayer, .chinese)
        XCTAssertEqual(session.commitSelection(), "是")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testPhraseCandidateRanksAheadOfShortPrefixCandidates() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "haopingguo")

        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "好苹果")
        XCTAssertTrue(session.snapshot.items.contains(where: { $0.candidate.surface == "好" }))
        XCTAssertEqual(session.snapshot.markedText, "hao ping guo")
    }

    func testAmbiguousPinyinMarkedTextFollowsSelectedCandidateParsing() {
        let westernCapitalSession = makeSessionWithEngine(
            snapshotsByInput: [
                "xian": CompositionSnapshot(
                    rawInput: "xian",
                    markedText: "xian",
                    candidates: [
                        Candidate(
                            id: "stub:xian:xi-an",
                            surface: "西安",
                            reading: "xi an",
                            score: 2,
                            consumedTokenCount: 2
                        ),
                        Candidate(
                            id: "stub:xian:xian",
                            surface: "先",
                            reading: "xian",
                            score: 1,
                            consumedTokenCount: 1
                        ),
                    ],
                    selectedIndex: 0,
                    pageIndex: 0,
                    isComposing: true,
                    activeRawInput: "xian",
                    remainingRawInput: "",
                    consumedTokenCount: 2
                )
            ],
            commitResult: CommitResult(committedText: "西安", snapshot: .idle)
        )

        westernCapitalSession.append(text: "xian")

        XCTAssertEqual(westernCapitalSession.snapshot.rawInput, "xian")
        XCTAssertEqual(westernCapitalSession.snapshot.markedText, "xi an")

        let singleSyllableSession = makeSessionWithEngine(
            snapshotsByInput: [
                "xian": CompositionSnapshot(
                    rawInput: "xian",
                    markedText: "xian",
                    candidates: [
                        Candidate(
                            id: "stub:xian:xi-an",
                            surface: "西安",
                            reading: "xi an",
                            score: 2,
                            consumedTokenCount: 2
                        ),
                        Candidate(
                            id: "stub:xian:xian",
                            surface: "先",
                            reading: "xian",
                            score: 1,
                            consumedTokenCount: 1
                        ),
                    ],
                    selectedIndex: 1,
                    pageIndex: 0,
                    isComposing: true,
                    activeRawInput: "xian",
                    remainingRawInput: "",
                    consumedTokenCount: 1
                )
            ],
            commitResult: CommitResult(committedText: "先", snapshot: .idle)
        )

        singleSyllableSession.append(text: "xian")

        XCTAssertEqual(singleSyllableSession.snapshot.rawInput, "xian")
        XCTAssertEqual(singleSyllableSession.snapshot.markedText, "xian")
    }

    func testEnglishPrefixCandidatePartiallyCommitsAndKeepsTail() async {
        let session = DemoFixtures.makeBilingualSession()
        let ready = expectation(description: "english preview ready for 好")
        var didFulfill = false

        session.onSnapshotUpdate = { snapshot in
            guard !didFulfill else { return }
            guard snapshot.activeLayer == .english,
                snapshot.items.count > 1,
                snapshot.items[1].candidate.surface == "好",
                snapshot.items[1].englishText == "good"
            else {
                return
            }
            didFulfill = true
            ready.fulfill()
        }

        session.append(text: "haopingguo")
        session.setActiveLayer(.english)
        session.moveColumn(.next)
        await fulfillment(of: [ready], timeout: 1.0)

        XCTAssertEqual(session.commitSelection(), "good")
        XCTAssertEqual(session.snapshot.rawInput, "pingguo")
        XCTAssertEqual(session.snapshot.markedText, "ping guo")
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "苹果")
        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testChinesePrefixCandidatePartiallyCommitsAndKeepsTail() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "haopingguo")
        session.moveColumn(.next)

        XCTAssertEqual(session.commitSelection(), "好")
        XCTAssertEqual(session.snapshot.rawInput, "pingguo")
        XCTAssertEqual(session.snapshot.markedText, "ping guo")
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "苹果")
        XCTAssertEqual(session.snapshot.activeLayer, .chinese)
    }

    func testBackspaceAfterPartialCommitOnlyEditsTail() async {
        let session = DemoFixtures.makeBilingualSession()
        let ready = expectation(description: "english preview ready for 好")
        var didFulfill = false

        session.onSnapshotUpdate = { snapshot in
            guard !didFulfill else { return }
            guard snapshot.activeLayer == .english,
                snapshot.items.count > 1,
                snapshot.items[1].candidate.surface == "好",
                snapshot.items[1].englishText == "good"
            else {
                return
            }
            didFulfill = true
            ready.fulfill()
        }

        session.append(text: "haopingguo")
        session.setActiveLayer(.english)
        session.moveColumn(.next)
        await fulfillment(of: [ready], timeout: 1.0)

        XCTAssertEqual(session.commitSelection(), "good")

        session.deleteBackward()

        XCTAssertEqual(session.snapshot.rawInput, "pinggu")
        XCTAssertEqual(session.snapshot.markedText, "pinggu")
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

    func testOnlySelectedCandidateStartsPreview() async {
        let session = DemoFixtures.makeBilingualSession(delay: .milliseconds(40))

        session.append(text: "haopingguo")

        XCTAssertEqual(session.snapshot.items.first?.previewState, .loading)
        XCTAssertEqual(session.snapshot.items.dropFirst().first?.previewState, .unavailable)

        session.moveColumn(.next)

        XCTAssertEqual(session.snapshot.items.first?.previewState, .unavailable)
        XCTAssertEqual(session.snapshot.items.dropFirst().first?.previewState, .loading)
    }

    func testStalePreviewAfterCancelDoesNotPublishComposingSnapshot() async {
        let session = DemoFixtures.makeBilingualSession(delay: .milliseconds(80))
        var snapshots: [BilingualCompositionSnapshot] = []
        session.onSnapshotUpdate = { snapshot in
            snapshots.append(snapshot)
        }

        session.append(text: "nihao")
        let composingRevision = session.snapshot.revision
        session.cancel()

        try? await Task.sleep(for: .milliseconds(180))

        XCTAssertFalse(session.snapshot.isComposing)
        XCTAssertFalse(
            snapshots.contains {
                $0.revision > composingRevision && $0.isComposing
            }
        )
    }
    func testAppendIgnoresNonAsciiLettersForPinyinQuery() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "你")

        XCTAssertEqual(session.snapshot, .idle)
    }

    func testWholePhraseCommitClearsCompositionEvenIfEngineReturnsStaleComposingSnapshot() {
        let session = makeSessionWithEngine(
            snapshotsByInput: [
                "nihao": CompositionSnapshot(
                    rawInput: "nihao",
                    markedText: "nihao",
                    candidates: [
                        Candidate(
                            id: "stub:nihao",
                            surface: "你好",
                            reading: "ni hao",
                            score: 1,
                            consumedTokenCount: 2
                        )
                    ],
                    selectedIndex: 0,
                    pageIndex: 0,
                    isComposing: true,
                    activeRawInput: "nihao",
                    remainingRawInput: "",
                    consumedTokenCount: 2
                )
            ],
            commitResult: CommitResult(
                committedText: "你好",
                snapshot: CompositionSnapshot(
                    rawInput: "nihao",
                    markedText: "nihao",
                    candidates: [
                        Candidate(
                            id: "stub:nihao",
                            surface: "你好",
                            reading: "ni hao",
                            score: 1,
                            consumedTokenCount: 2
                        )
                    ],
                    selectedIndex: 0,
                    pageIndex: 0,
                    isComposing: true,
                    activeRawInput: "nihao",
                    remainingRawInput: "",
                    consumedTokenCount: 2
                )
            )
        )

        session.append(text: "nihao")

        XCTAssertEqual(session.commitChineseSelection(), "你好")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testWholePhraseCommitClearsCompositionWhenConsumedSpanCannotBeProven() {
        let session = makeSessionWithEngine(
            snapshotsByInput: [
                "zhegea": CompositionSnapshot(
                    rawInput: "zhegea",
                    markedText: "zhegea",
                    candidates: [
                        Candidate(
                            id: "stub:zhegea",
                            surface: "這個啊",
                            reading: "",
                            score: 1,
                            consumedTokenCount: 0
                        )
                    ],
                    selectedIndex: 0,
                    pageIndex: 0,
                    isComposing: true,
                    activeRawInput: "",
                    remainingRawInput: "zhegea",
                    consumedTokenCount: 0
                )
            ],
            commitResult: CommitResult(
                committedText: "這個啊",
                snapshot: CompositionSnapshot(
                    rawInput: "zhegea",
                    markedText: "zhegea",
                    candidates: [
                        Candidate(
                            id: "stub:zhegea",
                            surface: "這個啊",
                            reading: "",
                            score: 1,
                            consumedTokenCount: 0
                        )
                    ],
                    selectedIndex: 0,
                    pageIndex: 0,
                    isComposing: true,
                    activeRawInput: "",
                    remainingRawInput: "zhegea",
                    consumedTokenCount: 0
                )
            )
        )

        session.append(text: "zhegea")

        XCTAssertEqual(session.commitChineseSelection(), "這個啊")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testWholePhraseCommitDoesNotReuseRemainingRawInputWhenConsumedSpanIsZero() {
        let session = makeSessionWithEngine(
            snapshotsByInput: [
                "shuangyu": CompositionSnapshot(
                    rawInput: "shuangyu",
                    markedText: "shuangyu",
                    candidates: [
                        Candidate(
                            id: "stub:shuangyu",
                            surface: "雙魚",
                            reading: "",
                            score: 1,
                            consumedTokenCount: 0
                        )
                    ],
                    selectedIndex: 0,
                    pageIndex: 0,
                    isComposing: true,
                    activeRawInput: "",
                    remainingRawInput: "shuangyu",
                    consumedTokenCount: 0
                )
            ],
            commitResult: CommitResult(
                committedText: "雙魚",
                snapshot: .idle
            )
        )

        session.append(text: "shuangyu")

        XCTAssertEqual(session.commitChineseSelection(), "雙魚")
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testPrefixCommitKeepsTailWhenEngineReturnsIdleSnapshot() {
        let session = makeSessionWithEngine(
            snapshotsByInput: [
                "haopingguo": CompositionSnapshot(
                    rawInput: "haopingguo",
                    markedText: "haopingguo",
                    candidates: [
                        Candidate(
                            id: "stub:hao",
                            surface: "好",
                            reading: "hao",
                            score: 1,
                            consumedTokenCount: 1
                        )
                    ],
                    selectedIndex: 0,
                    pageIndex: 0,
                    isComposing: true,
                    activeRawInput: "hao",
                    remainingRawInput: "pingguo",
                    consumedTokenCount: 1
                ),
                "pingguo": CompositionSnapshot(
                    rawInput: "pingguo",
                    markedText: "pingguo",
                    candidates: [],
                    selectedIndex: 0,
                    pageIndex: 0,
                    isComposing: true,
                    activeRawInput: "",
                    remainingRawInput: "pingguo",
                    consumedTokenCount: 0
                ),
            ],
            commitResult: CommitResult(
                committedText: "好",
                snapshot: .idle
            )
        )

        session.append(text: "haopingguo")

        XCTAssertEqual(session.commitChineseSelection(), "好")
        XCTAssertTrue(session.snapshot.isComposing)
        XCTAssertEqual(session.snapshot.rawInput, "pingguo")
        XCTAssertEqual(session.snapshot.markedText, "pingguo")
    }

    private func abbreviatedHpgSnapshot(selectedIndex: Int = 0) -> CompositionSnapshot {
        let candidates = [
            Candidate(
                id: "stub:hpg:haopingguo",
                surface: "好苹果",
                reading: "hao ping guo",
                score: 2,
                consumedTokenCount: 3
            ),
            Candidate(
                id: "stub:hpg:hao",
                surface: "好",
                reading: "hao",
                score: 1,
                consumedTokenCount: 1
            ),
        ]
        let selectedIndex = min(max(0, selectedIndex), candidates.count - 1)
        return CompositionSnapshot(
            rawInput: "hpg",
            markedText: "hpg",
            candidates: candidates,
            selectedIndex: selectedIndex,
            pageIndex: 0,
            isComposing: true,
            activeRawInput: selectedIndex == 0 ? "hpg" : "h",
            remainingRawInput: selectedIndex == 0 ? "" : "pg",
            consumedTokenCount: selectedIndex == 0 ? 3 : 1
        )
    }

    private func abbreviatedPgSnapshot() -> CompositionSnapshot {
        CompositionSnapshot(
            rawInput: "pg",
            markedText: "pg",
            candidates: [
                Candidate(
                    id: "stub:pg:pingguo",
                    surface: "苹果",
                    reading: "ping guo",
                    score: 1,
                    consumedTokenCount: 2
                )
            ],
            selectedIndex: 0,
            pageIndex: 0,
            isComposing: true,
            activeRawInput: "pg",
            remainingRawInput: "",
            consumedTokenCount: 2
        )
    }

}
