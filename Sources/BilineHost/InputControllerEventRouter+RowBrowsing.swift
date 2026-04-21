import Foundation

extension InputControllerEventRouter {
    func rowBrowseAction(
        for event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction? {
        let matchedNextRow = isNextRowKey(event)
        let matchedPreviousRow = isPreviousRowKey(event)
        guard matchedNextRow || matchedPreviousRow else {
            return nil
        }

        guard state.isComposing else {
            return nil
        }

        switch state.compositionMode {
        case .candidateCompact:
            if matchedNextRow {
                return .expandAndAdvanceRow
            }
            return state.hasEverExpandedInCurrentComposition
                ? .collapseToCompactAndSelectFirst
                : .appendLiteral(previousRowLiteral(for: event))
        case .candidateExpanded:
            if matchedNextRow {
                return .browseNextRow
            }
            return state.selectedRow == 0 && state.pageIndex == 0
                ? .collapseToCompactAndSelectFirst
                : .browsePreviousRow
        case .rawBufferOnly:
            return .appendLiteral(
                matchedNextRow ? nextRowLiteral(for: event) : previousRowLiteral(for: event)
            )
        }
    }

    private func isNextRowKey(_ event: InputControllerEvent) -> Bool {
        let character = actualCharacter(for: event)
        if event.keyCode == InputControllerKeyBinding.equal, character == "=" {
            return true
        }

        if event.keyCode == InputControllerKeyBinding.rightBracket, character == "]" {
            return true
        }

        return character == "=" || character == "]"
    }

    private func isPreviousRowKey(_ event: InputControllerEvent) -> Bool {
        let character = actualCharacter(for: event)
        if event.keyCode == InputControllerKeyBinding.minus, character == "-" {
            return true
        }

        if event.keyCode == InputControllerKeyBinding.leftBracket, character == "[" {
            return true
        }

        return character == "-" || character == "["
    }

    private func nextRowLiteral(for event: InputControllerEvent) -> String {
        if actualCharacter(for: event) == "]" {
            return "]"
        }
        return "="
    }

    private func previousRowLiteral(for event: InputControllerEvent) -> String {
        if actualCharacter(for: event) == "[" {
            return "["
        }
        return "-"
    }
}
