import BilineCore
import Foundation

extension InputControllerEventRouter {
    func rowBrowseAction(
        for event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction? {
        let matchedNextRow = keyBindings.matches(role: .nextRowOrPage, event: event)
        let matchedPreviousRow = keyBindings.matches(role: .previousRowOrPage, event: event)
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

    /// Single-keystroke direct candidate selection bound to `candidate2`/
    /// `candidate3`. Only consumes the key while composing with candidates.
    /// Outside composition the same key (e.g. `;` or `'`) falls through and
    /// reaches the normal punctuation/letter handlers.
    func candidateChordSelection(
        for event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction? {
        guard state.isComposing, state.hasCandidates else {
            return nil
        }
        if keyBindings.matches(role: .candidate2, event: event), state.compactColumnCount >= 2 {
            return .selectColumn(1)
        }
        if keyBindings.matches(role: .candidate3, event: event), state.compactColumnCount >= 3 {
            return .selectColumn(2)
        }
        return nil
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
