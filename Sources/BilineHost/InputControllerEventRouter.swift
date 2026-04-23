import BilineCore
import Foundation

public final class InputControllerEventRouter: @unchecked Sendable {
    /// Mutable so the controller can hot-swap the policy when settings
    /// change without rebuilding the router. Default keeps existing behavior
    /// for tests and for IMEs that have not configured anything yet.
    public var keyBindings: KeyBindingPolicy

    public init(keyBindings: KeyBindingPolicy = .default) {
        self.keyBindings = keyBindings
    }

    public func reset() {}

    public func route(
        event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction {
        if event.type == .flagsChanged {
            return .passThrough
        }

        if let deletionAction = deletionAction(for: event, state: state) {
            return deletionAction
        }

        if let rawCursorAction = rawCursorAction(for: event, state: state) {
            return rawCursorAction
        }

        if event.modifierFlags.contains(.command) {
            return .passThrough
        }

        if event.modifierFlags.contains(.option) {
            return .passThrough
        }

        if let uppercaseLatinText = shiftedUppercaseLatinText(from: event) {
            return state.isComposing
                ? .appendLiteral(uppercaseLatinText)
                : .insertText(uppercaseLatinText)
        }

        if let candidateAction = candidateChordSelection(for: event, state: state) {
            return candidateAction
        }

        if let rowAction = rowBrowseAction(for: event, state: state) {
            return rowAction
        }

        if let literalAction = literalAppendAction(for: event, state: state) {
            return literalAction
        }

        switch event.keyCode {
        case InputControllerKeyBinding.tab:
            if state.isComposing && event.modifierFlags.contains(.shift) {
                return state.hasCandidates ? .toggleLayer : .consume
            }
            return .passThrough
        case InputControllerKeyBinding.returnKey:
            guard state.isComposing else { return .passThrough }
            return state.isExpandedPresentation || state.hasExplicitCandidateSelection
                ? .commit : .commitRawInput
        case InputControllerKeyBinding.space:
            return state.isComposing ? .commit : .passThrough
        case InputControllerKeyBinding.deleteBackward:
            return state.isComposing && state.canDeleteBackward ? .deleteBackward : .passThrough
        case InputControllerKeyBinding.escape:
            return state.isComposing ? .cancel : .passThrough
        case InputControllerKeyBinding.leftArrow:
            return plainHorizontalArrowAction(direction: .previous, state: state)
        case InputControllerKeyBinding.rightArrow:
            return plainHorizontalArrowAction(direction: .next, state: state)
        case InputControllerKeyBinding.upArrow:
            guard state.isComposing, state.hasCandidates else {
                return .passThrough
            }
            switch state.compositionMode {
            case .candidateExpanded:
                return state.selectedRow == 0
                    ? .collapseToCompactAndSelectFirst : .browsePreviousRow
            case .candidateCompact:
                return .browsePreviousRow
            case .rawBufferOnly:
                return .passThrough
            }
        case InputControllerKeyBinding.downArrow:
            guard state.isComposing, state.hasCandidates else {
                return .passThrough
            }
            switch state.compositionMode {
            case .candidateExpanded:
                return .browseNextRow
            case .candidateCompact:
                return .expandAndAdvanceRow
            case .rawBufferOnly:
                return .passThrough
            }
        case InputControllerKeyBinding.pageUp:
            return state.isComposing ? .turnPage(.previous) : .passThrough
        case InputControllerKeyBinding.pageDown:
            return state.isComposing ? .turnPage(.next) : .passThrough
        default:
            break
        }

        if state.isComposing,
            state.hasCandidates,
            let digitIndex = candidateColumnIndex(
                from: event,
                columnCount: state.compactColumnCount
            )
        {
            return .selectColumn(digitIndex)
        }

        if state.isComposing, let punctuation = terminatingPunctuationCommitText(from: event) {
            return .commitChineseAndInsert(punctuation)
        }

        if !state.isComposing,
            let punctuation = standalonePunctuationText(from: event, state: state)
        {
            return .insertText(punctuation)
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return .passThrough
        }

        let normalized = pinyinInput(from: characters)
        return normalized.isEmpty ? .passThrough : .append(normalized)
    }

    private func plainHorizontalArrowAction(
        direction: SelectionDirection,
        state: InputControllerState
    ) -> InputControllerAction {
        guard state.isComposing else {
            return .passThrough
        }

        if state.compositionMode == .rawBufferOnly || !state.isRawCursorAtEnd {
            return .moveRawCursorByCharacter(direction)
        }

        return state.hasCandidates ? .moveColumn(direction) : .consume
    }

    private func deletionAction(
        for event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction? {
        guard event.keyCode == InputControllerKeyBinding.deleteBackward else {
            return nil
        }
        guard state.isComposing, state.canDeleteBackward else {
            return nil
        }

        let hasCommand = event.modifierFlags.contains(.command)
        let hasOption = event.modifierFlags.contains(.option)
        if hasCommand {
            return .deleteRawToStart
        }
        if hasOption {
            return .deleteRawBackwardByBlock
        }
        return .deleteBackward
    }

    private func rawCursorAction(
        for event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction? {
        guard state.isComposing else {
            return nil
        }

        let hasCommand = event.modifierFlags.contains(.command)
        let hasOption = event.modifierFlags.contains(.option)
        guard hasCommand || hasOption else {
            return nil
        }

        switch event.keyCode {
        case InputControllerKeyBinding.leftArrow:
            guard !state.hasExplicitCandidateSelection,
                !state.isExpandedPresentation,
                !event.modifierFlags.contains(.shift),
                hasCommand != hasOption
            else {
                return .consume
            }
            return hasCommand ? .moveRawCursorToStart : .moveRawCursorByBlock(.previous)
        case InputControllerKeyBinding.rightArrow:
            guard !state.hasExplicitCandidateSelection,
                !state.isExpandedPresentation,
                !event.modifierFlags.contains(.shift),
                hasCommand != hasOption
            else {
                return .consume
            }
            return hasCommand ? .moveRawCursorToEnd : .moveRawCursorByBlock(.next)
        default:
            return nil
        }
    }
}
