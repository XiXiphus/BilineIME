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
    public static let option = InputModifierFlags(rawValue: 1 << 2)
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
