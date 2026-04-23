import BilineCore
import BilineHost
import XCTest

final class InputControllerEventRouterTests: XCTestCase {
    func testBackspacePassesThroughWhenNotComposing() {
        let router = InputControllerEventRouter()

        let action = router.route(
            event: InputControllerEvent(type: .keyDown, keyCode: 51),
            state: InputControllerState(
                isComposing: false,
                canDeleteBackward: false,
                hasCandidates: false,
                compactColumnCount: 5
            )
        )

        XCTAssertEqual(action, .passThrough)
    }

    func testBackspaceDeletesOnlyWhenSessionCanDelete() {
        let router = InputControllerEventRouter()
        let composingState = InputControllerState(
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )
        let emptyState = InputControllerState(
            isComposing: true,
            canDeleteBackward: false,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 51),
                state: composingState
            ),
            .deleteBackward
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 51),
                state: emptyState
            ),
            .passThrough
        )
    }

    func testModifiedBackspaceDeletesInsideComposition() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 51,
                    modifierFlags: [.option]
                ),
                state: state
            ),
            .deleteRawBackwardByBlock
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 51,
                    modifierFlags: [.command]
                ),
                state: state
            ),
            .deleteRawToStart
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 51,
                    modifierFlags: [.shift, .option]
                ),
                state: state
            ),
            .deleteRawBackwardByBlock
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 51,
                    modifierFlags: [.shift, .command]
                ),
                state: state
            ),
            .deleteRawToStart
        )
    }

    func testModifiedBackspaceStillDeletesInsideCompositionAfterCandidateSelection() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            hasExplicitCandidateSelection: true
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 51,
                    modifierFlags: [.option]
                ),
                state: state
            ),
            .deleteRawBackwardByBlock
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 51,
                    modifierFlags: [.command]
                ),
                state: state
            ),
            .deleteRawToStart
        )
    }

    func testReturnCommitsRawInputBeforeExpansionOrSelection() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            isExpandedPresentation: false,
            hasExplicitCandidateSelection: false
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 36),
                state: state
            ),
            .commitRawInput
        )
    }

    func testReturnCommitsSelectedCandidateAfterExpansionOrSelection() {
        let router = InputControllerEventRouter()

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 36),
                state: InputControllerState(
                    compositionMode: .candidateExpanded,
                    isComposing: true,
                    canDeleteBackward: true,
                    hasCandidates: true,
                    compactColumnCount: 5,
                    isExpandedPresentation: true
                )
            ),
            .commit
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 36),
                state: InputControllerState(
                    compositionMode: .candidateCompact,
                    isComposing: true,
                    canDeleteBackward: true,
                    hasCandidates: true,
                    compactColumnCount: 5,
                    hasExplicitCandidateSelection: true
                )
            ),
            .commit
        )
    }

    func testSpaceStillCommitsSelectedCandidateInCompactMode() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 49),
                state: state
            ),
            .commit
        )
    }

    func testArrowKeysPassThroughWhenNotComposing() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: false,
            canDeleteBackward: false,
            hasCandidates: false,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 123),
                state: state
            ),
            .passThrough
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 124),
                state: state
            ),
            .passThrough
        )
    }

    func testPlainHorizontalArrowsBrowseCandidatesOnlyWhenRawCursorIsAtEnd() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            rawCursorIndex: 5,
            rawInputLength: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 123),
                state: state
            ),
            .moveColumn(.previous)
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 124),
                state: state
            ),
            .moveColumn(.next)
        )
    }

    func testPlainHorizontalArrowsMoveRawCursorWhenCursorIsNotAtEnd() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            rawCursorIndex: 2,
            rawInputLength: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 123),
                state: state
            ),
            .moveRawCursorByCharacter(.previous)
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 124),
                state: state
            ),
            .moveRawCursorByCharacter(.next)
        )
    }

    func testPlainHorizontalArrowsStayInsideRawBufferOnlyComposition() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .rawBufferOnly,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: false,
            compactColumnCount: 5,
            rawCursorIndex: 5,
            rawInputLength: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 123),
                state: state
            ),
            .moveRawCursorByCharacter(.previous)
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 124),
                state: state
            ),
            .moveRawCursorByCharacter(.next)
        )
    }

    func testOptionArrowMovesRawCursorBeforeExplicitCandidateSelection() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            hasExplicitCandidateSelection: false
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 123,
                    modifierFlags: [.option]
                ),
                state: state
            ),
            .moveRawCursorByBlock(.previous)
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 124,
                    modifierFlags: [.option]
                ),
                state: state
            ),
            .moveRawCursorByBlock(.next)
        )
    }

    func testCommandArrowMovesRawCursorToEdgesBeforeExplicitCandidateSelection() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            hasExplicitCandidateSelection: false
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 123,
                    modifierFlags: [.command]
                ),
                state: state
            ),
            .moveRawCursorToStart
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 124,
                    modifierFlags: [.command]
                ),
                state: state
            ),
            .moveRawCursorToEnd
        )
    }

    func testModifiedArrowsAreConsumedAfterExplicitCandidateSelection() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            hasExplicitCandidateSelection: true
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 123,
                    modifierFlags: [.option]
                ),
                state: state
            ),
            .consume
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 124,
                    modifierFlags: [.command]
                ),
                state: state
            ),
            .consume
        )
    }

    func testShiftModifiedRawCursorShortcutsAreConsumed() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 123,
                    modifierFlags: [.shift, .option]
                ),
                state: state
            ),
            .consume
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 124,
                    modifierFlags: [.shift, .command]
                ),
                state: state
            ),
            .consume
        )
    }

    func testOptionNonArrowKeysPassThrough() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 0,
                    characters: "å",
                    charactersIgnoringModifiers: "a",
                    modifierFlags: [.option]
                ),
                state: state
            ),
            .passThrough
        )
    }

    func testUpDownBrowseRowsWhileComposingWithCandidates() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 126),
                state: state
            ),
            .browsePreviousRow
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 125),
                state: state
            ),
            .expandAndAdvanceRow
        )
    }

    func testShiftPassesThroughDuringComposition() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .flagsChanged,
                    keyCode: 56,
                    modifierFlags: [.shift]
                ),
                state: state
            ),
            .passThrough
        )
    }

    func testShiftTabTogglesLayerDuringComposition() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 48,
                    characters: "\t",
                    charactersIgnoringModifiers: "\t",
                    modifierFlags: [.shift]
                ),
                state: state
            ),
            .toggleLayer
        )
    }

    func testTabPassesThroughDuringComposition() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 48,
                    characters: "\t",
                    charactersIgnoringModifiers: "\t"
                ),
                state: state
            ),
            .passThrough
        )
    }

    func testShiftTabConsumesWhenComposingWithoutCandidates() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .rawBufferOnly,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: false,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 48,
                    characters: "\t",
                    charactersIgnoringModifiers: "\t",
                    modifierFlags: [.shift]
                ),
                state: state
            ),
            .consume
        )
    }

    func testEqualPhysicalKeyExpandsAndAdvancesRowWhenCompact() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 24,
                    characters: "=",
                    charactersIgnoringModifiers: "="
                ),
                state: state
            ),
            .expandAndAdvanceRow
        )
    }

    func testEqualPhysicalKeyBrowsesNextRowWhenExpanded() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateExpanded,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            selectedRow: 1,
            isExpandedPresentation: true
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 24,
                    characters: "=",
                    charactersIgnoringModifiers: "="
                ),
                state: state
            ),
            .browseNextRow
        )
    }

    func testEqualPhysicalKeyUsesBilinePunctuationWhenNotComposing() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: false,
            canDeleteBackward: false,
            hasCandidates: false,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 24,
                    characters: "=",
                    charactersIgnoringModifiers: "="
                ),
                state: state
            ),
            .insertText("＝")
        )
    }

    func testDigitSelectsVisibleColumnOnlyWhileComposing() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 18,
                    charactersIgnoringModifiers: "3"
                ),
                state: state
            ),
            .selectColumn(2)
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 18,
                    charactersIgnoringModifiers: "6"
                ),
                state: state
            ),
            .passThrough
        )
    }

    func testHyphenMovesToPreviousRowWhileExpandedAndNotOnFirstRow() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateExpanded,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            selectedRow: 1,
            isExpandedPresentation: true
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 27,
                    characters: "-",
                    charactersIgnoringModifiers: "-"
                ),
                state: state
            ),
            .browsePreviousRow
        )
    }

    func testHyphenCollapsesToCompactAndSelectsFirstWhenExpandedAtFirstRow() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateExpanded,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            selectedRow: 0,
            isExpandedPresentation: true
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 27,
                    characters: "-",
                    charactersIgnoringModifiers: "-"
                ),
                state: state
            ),
            .collapseToCompactAndSelectFirst
        )
    }

    func testHyphenBrowsesPreviousRowWhenExpandedAtFirstRowOnLaterPage() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateExpanded,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            pageIndex: 1,
            selectedRow: 0,
            isExpandedPresentation: true
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 27,
                    characters: "-",
                    charactersIgnoringModifiers: "-"
                ),
                state: state
            ),
            .browsePreviousRow
        )
    }

    func testHyphenAppendsLiteralWhenCompactAndNeverExpanded() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            selectedRow: 0,
            isExpandedPresentation: false,
            hasEverExpandedInCurrentComposition: false
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 27,
                    characters: "-",
                    charactersIgnoringModifiers: "-"
                ),
                state: state
            ),
            .appendLiteral("-")
        )
    }

    func testHyphenCollapsesToFirstWhenCompactAfterExpansionHistory() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            hasEverExpandedInCurrentComposition: true
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 27,
                    characters: "-",
                    charactersIgnoringModifiers: "-"
                ),
                state: state
            ),
            .collapseToCompactAndSelectFirst
        )
    }

    func testRawBufferOnlyMinusAppendsLiteral() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .rawBufferOnly,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: false,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 27,
                    characters: "-",
                    charactersIgnoringModifiers: "-"
                ),
                state: state
            ),
            .appendLiteral("-")
        )
    }

    func testRawBufferOnlyEqualAppendsLiteral() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .rawBufferOnly,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: false,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 24,
                    characters: "=",
                    charactersIgnoringModifiers: "="
                ),
                state: state
            ),
            .appendLiteral("=")
        )
    }

    func testPlusAppendsLiteralDuringComposition() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 24,
                    characters: "+",
                    charactersIgnoringModifiers: "="
                ),
                state: state
            ),
            .appendLiteral("+")
        )
    }

    func testUnderscoreAppendsLiteralDuringComposition() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 27,
                    characters: "_",
                    charactersIgnoringModifiers: "-"
                ),
                state: state
            ),
            .appendLiteral("_")
        )
    }

    func testPercentAppendsLiteralDuringComposition() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 23,
                    characters: "%",
                    charactersIgnoringModifiers: "5"
                ),
                state: state
            ),
            .appendLiteral("%")
        )
    }

    func testCommaStillCommitsChineseAndInsertsPunctuationWhileComposing() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 43,
                    characters: ",",
                    charactersIgnoringModifiers: ","
                ),
                state: state
            ),
            .commitChineseAndInsert(",")
        )
    }

    func testFullwidthPunctuationIsInsertedWhenNotComposing() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: false,
            canDeleteBackward: false,
            hasCandidates: false,
            compactColumnCount: 5,
            punctuationForm: .fullwidth
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 43,
                    characters: ",",
                    charactersIgnoringModifiers: ","
                ),
                state: state
            ),
            .insertText("，")
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 29,
                    characters: ")",
                    charactersIgnoringModifiers: "0"
                ),
                state: state
            ),
            .insertText("）")
        )
    }

    func testHalfwidthPunctuationIsInsertedWhenNotComposing() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: false,
            canDeleteBackward: false,
            hasCandidates: false,
            compactColumnCount: 5,
            punctuationForm: .halfwidth
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 43,
                    characters: ",",
                    charactersIgnoringModifiers: ","
                ),
                state: state
            ),
            .insertText(",")
        )
    }

    func testHyphenUsesBilinePunctuationWhenNotComposing() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: false,
            canDeleteBackward: false,
            hasCandidates: false,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 27,
                    characters: "-",
                    charactersIgnoringModifiers: "-"
                ),
                state: state
            ),
            .insertText("－")
        )
    }
    func testAsciiLettersNormalizeToLowercasePinyinInput() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: false,
            canDeleteBackward: false,
            hasCandidates: false,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 45,
                    characters: "N",
                    charactersIgnoringModifiers: "N"
                ),
                state: state
            ),
            .append("n")
        )
    }

    func testNonAsciiLettersDoNotEnterPinyinComposition() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: false,
            canDeleteBackward: false,
            hasCandidates: false,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 0,
                    characters: "你",
                    charactersIgnoringModifiers: "你"
                ),
                state: state
            ),
            .passThrough
        )
    }

    // MARK: - KeyBindingPolicy integration

    func testCustomCandidate2BindingFiresSelectColumn1WhileComposing() {
        let policy = KeyBindingPolicy(bindings: [
            .candidate2: [KeyChord(character: ";")],
        ])
        let router = InputControllerEventRouter(keyBindings: policy)
        let composing = InputControllerState(
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 41,
                    characters: ";",
                    charactersIgnoringModifiers: ";"
                ),
                state: composing
            ),
            .selectColumn(1)
        )
    }

    func testCustomCandidate3BindingFallsThroughWhenNotComposing() {
        // Outside composition the same chord must NOT be eaten by the router;
        // it should fall through to the standalone-punctuation handler so the
        // host receives the literal character.
        let policy = KeyBindingPolicy(bindings: [
            .candidate3: [KeyChord(character: "'")],
        ])
        let router = InputControllerEventRouter(keyBindings: policy)
        let idle = InputControllerState(
            isComposing: false,
            canDeleteBackward: false,
            hasCandidates: false,
            compactColumnCount: 5
        )

        let action = router.route(
            event: InputControllerEvent(
                type: .keyDown,
                keyCode: 39,
                characters: "'",
                charactersIgnoringModifiers: "'"
            ),
            state: idle
        )

        if case .selectColumn = action {
            XCTFail("Candidate-selection chord must not fire while idle")
        }
    }

    func testCustomNextRowBindingTriggersExpansion() {
        // Remap nextRowOrPage to "." (period) instead of "=" and verify the
        // router uses the new binding for compact-mode expansion. Existing
        // bindings (=, ]) remain in defaults but the router should also
        // accept the user override.
        let policy = KeyBindingPolicy(bindings: [
            .nextRowOrPage: [KeyChord(character: ".", keyCode: 47)],
        ])
        let router = InputControllerEventRouter(keyBindings: policy)
        let compact = InputControllerState(
            compositionMode: .candidateCompact,
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .keyDown,
                    keyCode: 47,
                    characters: ".",
                    charactersIgnoringModifiers: "."
                ),
                state: compact
            ),
            .expandAndAdvanceRow
        )
    }
}
