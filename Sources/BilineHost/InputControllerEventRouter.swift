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
    public let isExpandedPresentation: Bool

    public init(
        isComposing: Bool,
        canDeleteBackward: Bool,
        hasCandidates: Bool,
        compactColumnCount: Int,
        isExpandedPresentation: Bool = false
    ) {
        self.isComposing = isComposing
        self.canDeleteBackward = canDeleteBackward
        self.hasCandidates = hasCandidates
        self.compactColumnCount = max(1, compactColumnCount)
        self.isExpandedPresentation = isExpandedPresentation
    }
}

public enum InputControllerAction: Sendable, Equatable {
    case passThrough
    case consume
    case append(String)
    case deleteBackward
    case commit
    case cancel
    case moveColumn(SelectionDirection)
    case moveRow(SelectionDirection)
    case turnPage(PageDirection)
    case toggleLayer
    case togglePresentation
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
        static let keypadPlus: UInt16 = 69
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

        if isExpansionToggle(event) {
            return state.isComposing ? .togglePresentation : .passThrough
        }

        switch event.keyCode {
        case KeyBinding.returnKey, KeyBinding.space:
            return state.isComposing ? .commit : .passThrough
        case KeyBinding.deleteBackward:
            return state.isComposing && state.canDeleteBackward ? .deleteBackward : .passThrough
        case KeyBinding.escape:
            return state.isComposing ? .cancel : .passThrough
        case KeyBinding.leftArrow:
            return state.isComposing ? .moveColumn(.previous) : .passThrough
        case KeyBinding.rightArrow:
            return state.isComposing ? .moveColumn(.next) : .passThrough
        case KeyBinding.upArrow:
            guard state.isComposing, state.isExpandedPresentation else {
                return .passThrough
            }
            return .moveRow(.previous)
        case KeyBinding.downArrow:
            guard state.isComposing, state.isExpandedPresentation else {
                return .passThrough
            }
            return .moveRow(.next)
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

    private func isExpansionToggle(_ event: InputControllerEvent) -> Bool {
        if event.keyCode == KeyBinding.keypadPlus {
            return true
        }

        if event.keyCode == KeyBinding.equal {
            let reportedCharacters = [event.characters, event.charactersIgnoringModifiers]
                .compactMap { $0 }
            if reportedCharacters.contains("+") || reportedCharacters.contains("=") {
                return true
            }
        }

        return event.characters == "+" || event.charactersIgnoringModifiers == "+"
    }
}
