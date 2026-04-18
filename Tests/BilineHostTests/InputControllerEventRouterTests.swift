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

    func testEqualPhysicalKeyStillPassesThroughWhenNotComposing() {
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
            .passThrough
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

    func testHyphenPassesThroughWhenNotComposing() {
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
            .passThrough
        )
    }
}
