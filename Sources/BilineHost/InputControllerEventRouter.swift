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

public enum InputCompositionMode: Sendable, Equatable {
    case candidateCompact
    case candidateExpanded
    case rawBufferOnly
}

public struct InputControllerState: Sendable, Equatable {
    public let compositionMode: InputCompositionMode
    public let isComposing: Bool
    public let canDeleteBackward: Bool
    public let hasCandidates: Bool
    public let compactColumnCount: Int
    public let pageIndex: Int
    public let selectedRow: Int
    public let isExpandedPresentation: Bool
    public let hasEverExpandedInCurrentComposition: Bool

    public init(
        compositionMode: InputCompositionMode = .candidateCompact,
        isComposing: Bool,
        canDeleteBackward: Bool,
        hasCandidates: Bool,
        compactColumnCount: Int,
        pageIndex: Int = 0,
        selectedRow: Int = 0,
        isExpandedPresentation: Bool = false,
        hasEverExpandedInCurrentComposition: Bool = false
    ) {
        self.compositionMode = compositionMode
        self.isComposing = isComposing
        self.canDeleteBackward = canDeleteBackward
        self.hasCandidates = hasCandidates
        self.compactColumnCount = max(1, compactColumnCount)
        self.pageIndex = max(0, pageIndex)
        self.selectedRow = max(0, selectedRow)
        self.isExpandedPresentation = isExpandedPresentation
        self.hasEverExpandedInCurrentComposition = hasEverExpandedInCurrentComposition
    }
}

public enum InputControllerAction: Sendable, Equatable {
    case passThrough
    case consume
    case append(String)
    case appendLiteral(String)
    case commitChineseAndInsert(String)
    case toggleLayer
    case deleteBackward
    case commit
    case cancel
    case moveColumn(SelectionDirection)
    case browseNextRow
    case browsePreviousRow
    case expandAndAdvanceRow
    case collapseToCompactAndSelectFirst
    case turnPage(PageDirection)
    case selectColumn(Int)
}

public final class InputControllerEventRouter: @unchecked Sendable {
    private enum KeyBinding {
        static let tab: UInt16 = 48
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
    }

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
        case KeyBinding.tab:
            if state.isComposing && event.modifierFlags.contains(.shift) {
                return state.hasCandidates ? .toggleLayer : .consume
            }
            return .passThrough
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
            switch state.compositionMode {
            case .candidateExpanded:
                return state.selectedRow == 0 ? .collapseToCompactAndSelectFirst : .browsePreviousRow
            case .candidateCompact:
                return .browsePreviousRow
            case .rawBufferOnly:
                return .passThrough
            }
        case KeyBinding.downArrow:
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

        if state.isComposing, let punctuation = terminatingPunctuationCommitText(from: event) {
            return .commitChineseAndInsert(punctuation)
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return .passThrough
        }

        let normalized = pinyinInput(from: characters)
        return normalized.isEmpty ? .passThrough : .append(normalized)
    }

    private func pinyinInput(from text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 65...90:
                result.unicodeScalars.append(UnicodeScalar(scalar.value + 32)!)
            case 97...122:
                result.unicodeScalars.append(scalar)
            case 39:
                result.append("'")
            default:
                continue
            }
        }

        return result
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

    private func terminatingPunctuationCommitText(from event: InputControllerEvent) -> String? {
        let candidates = [event.characters, event.charactersIgnoringModifiers].compactMap { $0 }
        let terminatingPunctuation: Set<String> = [",", ".", "!", "?", ";", ":"]

        for candidate in candidates where candidate.count == 1 {
            if terminatingPunctuation.contains(candidate) {
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

    private func literalAppendAction(
        for event: InputControllerEvent,
        state: InputControllerState
    ) -> InputControllerAction? {
        guard state.isComposing else {
            return nil
        }

        if let literal = genericLiteralPunctuation(for: event) {
            return .appendLiteral(literal)
        }

        return nil
    }

    private func genericLiteralPunctuation(for event: InputControllerEvent) -> String? {
        guard let character = actualCharacter(for: event), character.count == 1 else {
            return nil
        }

        guard let scalar = character.unicodeScalars.first, scalar.isASCII else {
            return nil
        }

        let value = scalar.value
        let isASCIIPunctuation =
            (33...47).contains(value)
            || (58...64).contains(value)
            || (91...96).contains(value)
            || (123...126).contains(value)
        guard isASCIIPunctuation else {
            return nil
        }

        let excludedLiterals: Set<String> = ["'", "-", "=", "[", "]", ",", ".", "!", "?", ";", ":"]
        return excludedLiterals.contains(character) ? nil : character
    }

    private func isNextRowKey(_ event: InputControllerEvent) -> Bool {
        let character = actualCharacter(for: event)
        if event.keyCode == KeyBinding.equal, character == "=" {
            return true
        }

        if event.keyCode == KeyBinding.rightBracket, character == "]" {
            return true
        }

        return character == "=" || character == "]"
    }

    private func isPreviousRowKey(_ event: InputControllerEvent) -> Bool {
        let character = actualCharacter(for: event)
        if event.keyCode == KeyBinding.minus, character == "-" {
            return true
        }

        if event.keyCode == KeyBinding.leftBracket, character == "[" {
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

    private func actualCharacter(for event: InputControllerEvent) -> String? {
        if let characters = event.characters, !characters.isEmpty {
            return characters
        }
        if let charactersIgnoringModifiers = event.charactersIgnoringModifiers,
            !charactersIgnoringModifiers.isEmpty
        {
            return charactersIgnoringModifiers
        }
        return nil
    }
}
