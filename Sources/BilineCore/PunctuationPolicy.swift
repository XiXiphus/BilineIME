import Foundation

public enum PunctuationForm: String, Sendable, Codable, CaseIterable {
    case fullwidth
    case halfwidth
}

public enum PunctuationPolicy {
    private static let chinesePunctuationOverrides: [Character: String] = [
        ",": "，",
        ".": "。",
        "!": "！",
        "?": "？",
        ";": "；",
        ":": "：",
    ]

    public static func renderPreedit(_ text: String, form: PunctuationForm) -> String {
        transform(text, form: form)
    }

    public static func renderCommittedText(_ text: String, form: PunctuationForm) -> String {
        transform(text, form: form)
    }

    public static func canHandle(_ text: String) -> Bool {
        guard text.count == 1, let character = text.first else {
            return false
        }
        return renderedCharacter(character, form: .fullwidth) != String(character)
            || isHandledASCII(character)
    }

    private static func transform(_ text: String, form: PunctuationForm) -> String {
        guard !text.isEmpty else { return text }

        return text.reduce(into: "") { result, character in
            result.append(renderedCharacter(character, form: form))
        }
    }

    private static func renderedCharacter(_ character: Character, form: PunctuationForm) -> String {
        switch form {
        case .halfwidth:
            return String(character)
        case .fullwidth:
            if let overridden = chinesePunctuationOverrides[character] {
                return overridden
            }

            guard character != "'" else {
                return String(character)
            }

            guard let scalar = character.unicodeScalars.first,
                character.unicodeScalars.count == 1,
                scalar.isASCII,
                isASCIIPunctuation(scalar.value),
                let fullwidthScalar = UnicodeScalar(scalar.value + 0xFEE0)
            else {
                return String(character)
            }

            return String(fullwidthScalar)
        }
    }

    private static func isHandledASCII(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first,
            character.unicodeScalars.count == 1,
            scalar.isASCII
        else {
            return false
        }
        return isASCIIPunctuation(scalar.value)
    }

    private static func isASCIIPunctuation(_ value: UInt32) -> Bool {
        (33...47).contains(value)
            || (58...64).contains(value)
            || (91...96).contains(value)
            || (123...126).contains(value)
    }
}
