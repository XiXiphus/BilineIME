import BilineCore
import Foundation

public final class InputControllerEventRouter: @unchecked Sendable {
    public init() {}

    public func reset() {}

    public func route(
        event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction {
        if event.type == .flagsChanged {
            return .passThrough
        }

        if event.modifierFlags.contains(.command) {
            return .passThrough
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
            return state.isComposing && state.hasCandidates ? .moveColumn(.previous) : .passThrough
        case InputControllerKeyBinding.rightArrow:
            return state.isComposing && state.hasCandidates ? .moveColumn(.next) : .passThrough
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
}
