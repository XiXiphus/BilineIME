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

    func testCompactModePassesThroughUpDownWhileComposing() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            isExpandedPresentation: false
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 126),
                state: state
            ),
            .passThrough
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 125),
                state: state
            ),
            .passThrough
        )
    }

    func testExpandedModeUsesUpDownForRowNavigation() {
        let router = InputControllerEventRouter()
        let state = InputControllerState(
            isComposing: true,
            canDeleteBackward: true,
            hasCandidates: true,
            compactColumnCount: 5,
            isExpandedPresentation: true
        )

        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 126),
                state: state
            ),
            .moveRow(.previous)
        )
        XCTAssertEqual(
            router.route(
                event: InputControllerEvent(type: .keyDown, keyCode: 125),
                state: state
            ),
            .moveRow(.next)
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

    func testShiftEqualTogglesPresentationDuringComposition() {
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
                    characters: "+",
                    charactersIgnoringModifiers: "=",
                    modifierFlags: [.shift]
                ),
                state: state
            ),
            .togglePresentation
        )
    }

    func testKeypadPlusTogglesPresentationDuringComposition() {
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
                    keyCode: 69,
                    characters: "+",
                    charactersIgnoringModifiers: "+"
                ),
                state: state
            ),
            .togglePresentation
        )
    }

    func testEqualPhysicalKeyTogglesPresentationWithoutShiftFlagWhenComposing() {
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
            .togglePresentation
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

    func testShiftModifierDoesNotToggleLayerAfterExpansionShortcut() {
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
                    type: .keyDown,
                    keyCode: 24,
                    characters: "+",
                    charactersIgnoringModifiers: "=",
                    modifierFlags: [.shift]
                ),
                state: state
            ),
            .togglePresentation
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
            .consume
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
}
