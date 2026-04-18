import BilineCore
import Foundation

public enum InputEventType: Sendable, Equatable {
    case keyDown
    case flagsChanged
}

public struct InputModifierFlags: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = InputModifierFlags(rawValue: 1 << 0)
    public static let command = InputModifierFlags(rawValue: 1 << 1)
}

public struct InputControllerEvent: Sendable, Equatable {
    public let type: InputEventType
    public let keyCode: UInt16
    public let characters: String?
    public let charactersIgnoringModifiers: String?
    public let modifierFlags: InputModifierFlags

    public init(
        type: InputEventType,
        keyCode: UInt16,
        characters: String? = nil,
        charactersIgnoringModifiers: String? = nil,
        modifierFlags: InputModifierFlags = []
    ) {
        self.type = type
        self.keyCode = keyCode
        self.characters = characters
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.modifierFlags = modifierFlags
    }
}

public struct InputControllerState: Sendable, Equatable {
    public let isComposing: Bool
    public let canDeleteBackward: Bool
    public let hasCandidates: Bool
    public let compactColumnCount: Int
    public let selectedRow: Int
    public let isExpandedPresentation: Bool

    public init(
        isComposing: Bool,
        canDeleteBackward: Bool,
        hasCandidates: Bool,
        compactColumnCount: Int,
        selectedRow: Int = 0,
        isExpandedPresentation: Bool = false
    ) {
        self.isComposing = isComposing
        self.canDeleteBackward = canDeleteBackward
        self.hasCandidates = hasCandidates
        self.compactColumnCount = max(1, compactColumnCount)
        self.selectedRow = max(0, selectedRow)
        self.isExpandedPresentation = isExpandedPresentation
    }
}

public enum InputControllerAction: Sendable, Equatable {
    case passThrough
    case consume
    case append(String)
    case commitChineseAndInsert(String)
    case deleteBackward
    case commit
    case cancel
    case moveColumn(SelectionDirection)
    case browseNextRow
    case browsePreviousRow
    case expandAndAdvanceRow
    case collapseToCompactAndSelectFirst
    case turnPage(PageDirection)
    case toggleLayer
    case selectColumn(Int)
}

public final class InputControllerEventRouter: @unchecked Sendable {
    private enum KeyBinding {
        static let returnKey: UInt16 = 36
        static let space: UInt16 = 49
        static let deleteBackward: UInt16 = 51
        static let escape: UInt16 = 53
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let pageUp: UInt16 = 116
        static let pageDown: UInt16 = 121
        static let equal: UInt16 = 24
        static let minus: UInt16 = 27
        static let leftBracket: UInt16 = 33
        static let rightBracket: UInt16 = 30
        static let leftShift: UInt16 = 56
        static let rightShift: UInt16 = 60
    }

    private var isShiftPressed = false
    private var shiftUsedAsModifier = false

    public init() {}

    public func reset() {
        isShiftPressed = false
        shiftUsedAsModifier = false
    }

    public func route(
        event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction {
        if event.type == .flagsChanged {
            return routeFlagsChanged(event: event, state: state)
        }

        if event.modifierFlags.contains(.command) {
            if isShiftPressed {
                shiftUsedAsModifier = true
            }
            return .passThrough
        }

        if isShiftPressed {
            shiftUsedAsModifier = true
        }

        if let rowAction = rowBrowseAction(for: event, state: state) {
            return rowAction
        }

        switch event.keyCode {
        case KeyBinding.returnKey, KeyBinding.space:
            return state.isComposing ? .commit : .passThrough
        case KeyBinding.deleteBackward:
            return state.isComposing && state.canDeleteBackward ? .deleteBackward : .passThrough
        case KeyBinding.escape:
            return state.isComposing ? .cancel : .passThrough
        case KeyBinding.leftArrow:
            return state.isComposing && state.hasCandidates ? .moveColumn(.previous) : .passThrough
        case KeyBinding.rightArrow:
            return state.isComposing && state.hasCandidates ? .moveColumn(.next) : .passThrough
        case KeyBinding.upArrow:
            guard state.isComposing, state.hasCandidates else {
                return .passThrough
            }
            return state.isExpandedPresentation && state.selectedRow == 0
                ? .collapseToCompactAndSelectFirst
                : .browsePreviousRow
        case KeyBinding.downArrow:
            guard state.isComposing, state.hasCandidates else {
                return .passThrough
            }
            return state.isExpandedPresentation ? .browseNextRow : .expandAndAdvanceRow
        case KeyBinding.pageUp:
            return state.isComposing ? .turnPage(.previous) : .passThrough
        case KeyBinding.pageDown:
            return state.isComposing ? .turnPage(.next) : .passThrough
        default:
            break
        }

        if state.isComposing,
            state.hasCandidates,
            let digitIndex = candidateColumnIndex(from: event, columnCount: state.compactColumnCount)
        {
            return .selectColumn(digitIndex)
        }

        if state.isComposing, let punctuation = punctuationCommitText(from: event) {
            return .commitChineseAndInsert(punctuation)
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return .passThrough
        }

        let normalized = characters.filter { $0.isLetter || $0 == "'" }
        return normalized.isEmpty ? .passThrough : .append(normalized)
    }

    private func routeFlagsChanged(
        event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction {
        guard event.keyCode == KeyBinding.leftShift || event.keyCode == KeyBinding.rightShift else {
            return .passThrough
        }

        let isShiftDown = event.modifierFlags.contains(.shift)
        guard state.isComposing else {
            isShiftPressed = isShiftDown
            shiftUsedAsModifier = false
            return .passThrough
        }

        if isShiftDown {
            isShiftPressed = true
            shiftUsedAsModifier = false
            return .consume
        }

        let shouldToggleLayer = isShiftPressed && !shiftUsedAsModifier
        isShiftPressed = false
        shiftUsedAsModifier = false
        return shouldToggleLayer ? .toggleLayer : .consume
    }

    private func candidateColumnIndex(
        from event: InputControllerEvent,
        columnCount: Int
    ) -> Int? {
        guard let characters = event.charactersIgnoringModifiers, characters.count == 1 else {
            return nil
        }

        guard let scalar = characters.unicodeScalars.first,
            CharacterSet.decimalDigits.contains(scalar),
            let value = Int(String(characters)),
            value >= 1
        else {
            return nil
        }

        let index = value - 1
        return index < columnCount ? index : nil
    }

    private func punctuationCommitText(from event: InputControllerEvent) -> String? {
        let candidates = [event.characters, event.charactersIgnoringModifiers].compactMap { $0 }

        for candidate in candidates where candidate.count == 1 {
            guard let scalar = candidate.unicodeScalars.first, scalar.isASCII else {
                continue
            }

            let value = scalar.value
            let isASCIIPunctuation =
                (33...47).contains(value)
                || (58...64).contains(value)
                || (91...96).contains(value)
                || (123...126).contains(value)
            let excluded = value == 39 || value == 43 || value == 45 || value == 61
                || value == 91 || value == 93

            if isASCIIPunctuation && !excluded {
                return candidate
            }
        }

        return nil
    }

    private func rowBrowseAction(
        for event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction? {
        let matchedNextRow = isNextRowKey(event)
        let matchedPreviousRow = isPreviousRowKey(event)
        guard matchedNextRow || matchedPreviousRow else {
            return nil
        }

        guard state.isComposing else {
            return .passThrough
        }

        guard state.hasCandidates else {
            return nil
        }

        if matchedNextRow {
            return state.isExpandedPresentation ? .browseNextRow : .expandAndAdvanceRow
        }

        return state.isExpandedPresentation && state.selectedRow == 0
            ? .collapseToCompactAndSelectFirst
            : .browsePreviousRow
    }

    private func isNextRowKey(_ event: InputControllerEvent) -> Bool {
        if event.keyCode == KeyBinding.equal {
            let reportedCharacters = [event.characters, event.charactersIgnoringModifiers]
                .compactMap { $0 }
            if reportedCharacters.contains("=") {
                return true
            }
        }

        if event.keyCode == KeyBinding.rightBracket {
            return event.characters == "]" || event.charactersIgnoringModifiers == "]"
        }

        return event.characters == "=" || event.charactersIgnoringModifiers == "="
            || event.characters == "]" || event.charactersIgnoringModifiers == "]"
    }

    private func isPreviousRowKey(_ event: InputControllerEvent) -> Bool {
        if event.keyCode == KeyBinding.minus {
            let reportedCharacters = [event.characters, event.charactersIgnoringModifiers]
                .compactMap { $0 }
            if reportedCharacters.contains("-") {
                return true
            }
        }

        if event.keyCode == KeyBinding.leftBracket {
            let reportedCharacters = [event.characters, event.charactersIgnoringModifiers]
                .compactMap { $0 }
            if reportedCharacters.contains("[") {
                return true
            }
        }

        return event.characters == "-" || event.charactersIgnoringModifiers == "-"
            || event.characters == "[" || event.charactersIgnoringModifiers == "["
    }
}
