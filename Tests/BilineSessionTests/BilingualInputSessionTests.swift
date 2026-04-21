import BilineCore
import BilinePreview
import BilineSession
import BilineTestSupport
import XCTest

final class BilingualInputSessionTests: XCTestCase {
    func testSetActiveLayerChangesLayerWithoutChangingCell() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "nihao")
        let before = session.snapshot

        session.setActiveLayer(.english)
        let after = session.snapshot

        XCTAssertEqual(before.selectedRow, after.selectedRow)
        XCTAssertEqual(before.selectedColumn, after.selectedColumn)
        XCTAssertEqual(before.selectedFlatIndex, after.selectedFlatIndex)
        XCTAssertEqual(after.activeLayer, .english)
    }

    func testToggleActiveLayerChangesLayerWithoutChangingCell() {
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
        session.setActiveLayer(.english)
        session.moveColumn(.next)

        XCTAssertEqual(session.snapshot.activeLayer, .english)
        XCTAssertEqual(session.snapshot.selectedRow, 0)
        XCTAssertEqual(session.snapshot.selectedColumn, 1)
        XCTAssertEqual(session.snapshot.selectedFlatIndex, 1)
    }

    func testAppendingInputKeepsEnglishLayerActive() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.setActiveLayer(.english)
        session.append(text: "a")

        XCTAssertEqual(session.snapshot.rawInput, "shia")
        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testToggleActiveLayerPersistsAcrossTypingAndBrowsing() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.toggleActiveLayer()
        session.append(text: "a")
        session.browseNextRow()

        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testBrowsingRowsKeepsEnglishLayerActive() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.setActiveLayer(.english)
        session.expandAndAdvanceRow()

        XCTAssertEqual(session.snapshot.selectedRow, 1)
        XCTAssertEqual(session.snapshot.activeLayer, .english)
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

    func testAppendLiteralSwitchesToRawBufferOnlyComposition() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.appendLiteral(text: "-")

        XCTAssertTrue(session.snapshot.isComposing)
        XCTAssertEqual(session.compositionMode, .rawBufferOnly)
        XCTAssertEqual(session.snapshot.rawInput, "shi-")
        XCTAssertEqual(session.snapshot.displayRawInput, "shi－")
        XCTAssertEqual(session.snapshot.markedText, "shi－")
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

    func testRawBufferOnlyCanAccumulateMinusEqualAndPlus() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "ni")
        session.appendLiteral(text: "-")
        session.appendLiteral(text: "-")
        session.appendLiteral(text: "=")
        session.appendLiteral(text: "=")
        session.appendLiteral(text: "+")

        XCTAssertEqual(session.compositionMode, .rawBufferOnly)
        XCTAssertEqual(session.snapshot.rawInput, "ni--==+")
        XCTAssertEqual(session.snapshot.displayRawInput, "ni－－＝＝＋")
        XCTAssertTrue(session.snapshot.items.isEmpty)
    }

    func testRawBufferOnlyDisplayUsesChinesePunctuationPolicy() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        session.appendLiteral(text: "%")
        session.appendLiteral(text: "_")
        session.appendLiteral(text: "+")

        XCTAssertEqual(session.compositionMode, .rawBufferOnly)
        XCTAssertEqual(session.snapshot.rawInput, "shi%_+")
        XCTAssertEqual(session.snapshot.displayRawInput, "shi％＿＋")
        XCTAssertEqual(session.snapshot.markedText, "shi％＿＋")
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

    func testPhraseCandidateRanksAheadOfShortPrefixCandidates() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "haopingguo")

        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "好苹果")
        XCTAssertTrue(session.snapshot.items.contains(where: { $0.candidate.surface == "好" }))
        XCTAssertEqual(session.snapshot.markedText, "haopingguo")
    }

    func testEnglishPhraseCandidateCommitsFullTranslation() async {
        let session = DemoFixtures.makeBilingualSession()
        let ready = expectation(description: "english preview ready for 好苹果")
        var didFulfill = false

        session.onSnapshotUpdate = { snapshot in
            guard !didFulfill else { return }
            guard snapshot.activeLayer == .english,
                snapshot.items.first?.candidate.surface == "好苹果",
                snapshot.items.first?.englishText == "good apple"
            else {
                return
            }
            didFulfill = true
            ready.fulfill()
        }

        session.append(text: "haopingguo")
        session.setActiveLayer(.english)
        await fulfillment(of: [ready], timeout: 1.0)

        XCTAssertEqual(session.commitSelection(), "good apple")
        XCTAssertEqual(session.snapshot, .idle)
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
        await fulfillment(of: [ready], timeout: 1.0)

        session.moveColumn(.next)

        XCTAssertEqual(session.commitSelection(), "good")
        XCTAssertEqual(session.snapshot.rawInput, "pingguo")
        XCTAssertEqual(session.snapshot.markedText, "pingguo")
        XCTAssertEqual(session.snapshot.items.first?.candidate.surface, "苹果")
        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testChinesePrefixCandidatePartiallyCommitsAndKeepsTail() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "haopingguo")
        session.moveColumn(.next)

        XCTAssertEqual(session.commitSelection(), "好")
        XCTAssertEqual(session.snapshot.rawInput, "pingguo")
        XCTAssertEqual(session.snapshot.markedText, "pingguo")
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
        await fulfillment(of: [ready], timeout: 1.0)

        session.moveColumn(.next)
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

}

private func makeSessionWithEngine(
    snapshotsByInput: [String: CompositionSnapshot],
    commitResult: CommitResult
) -> BilingualInputSession {
    BilingualInputSession(
        settingsStore: StubSettingsStore(),
        engineFactory: StubEngineFactory(
            session: StubCandidateEngineSession(
                snapshotsByInput: snapshotsByInput,
                commitResult: commitResult
            )
        ),
        previewCoordinator: DemoFixtures.makeCoordinator()
    )
}

private struct StubSettingsStore: SettingsStore {
    let targetLanguage: TargetLanguage = .english
    let previewEnabled: Bool = true
    let compactColumnCount: Int = 5
    let expandedRowCount: Int = 5
    let fuzzyPinyinEnabled: Bool = false
    let characterForm: CharacterForm = .simplified
    let punctuationForm: PunctuationForm = .fullwidth

    var pageSize: Int { compactColumnCount * expandedRowCount }
}

private struct StubEngineFactory: CandidateEngineFactory {
    let session: StubCandidateEngineSession

    func makeSession(config: EngineConfig) -> any CandidateEngineSession {
        session
    }
}

private final class StubCandidateEngineSession: CandidateEngineSession, @unchecked Sendable {
    private let snapshotsByInput: [String: CompositionSnapshot]
    private let commitResultValue: CommitResult

    init(snapshotsByInput: [String: CompositionSnapshot], commitResult: CommitResult) {
        self.snapshotsByInput = snapshotsByInput
        self.commitResultValue = commitResult
    }

    func updateInput(_ rawInput: String) -> CompositionSnapshot {
        snapshotsByInput[rawInput] ?? .idle
    }

    func moveSelection(_ direction: SelectionDirection) -> CompositionSnapshot {
        snapshotsByInput.values.first ?? .idle
    }

    func turnPage(_ direction: PageDirection) -> CompositionSnapshot {
        snapshotsByInput.values.first ?? .idle
    }

    func commitSelected() -> CommitResult {
        commitResultValue
    }

    func reset() -> CompositionSnapshot {
        .idle
    }
}
