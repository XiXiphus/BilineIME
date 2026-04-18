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

    func testShiftTapTogglesLayerDuringComposition() {
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
                    type: .flagsChanged,
                    keyCode: 56,
                    modifierFlags: [.shift]
                ),
                state: state
            ),
            .consume
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(
                    type: .flagsChanged,
                    keyCode: 56,
                    modifierFlags: []
                ),
                state: state
            ),
            .toggleLayer
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
