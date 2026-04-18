import Foundation

enum PunctuationPolicy {
    private static let chinesePunctuationOverrides: [Character: String] = [
        ",": "，",
        ".": "。",
        "!": "！",
        "?": "？",
        ";": "；",
        ":": "：",
    ]

    static func renderPreedit(_ text: String) -> String {
        transform(text)
    }

    static func renderCommittedText(_ text: String) -> String {
        transform(text)
    }

    private static func transform(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        return text.reduce(into: "") { result, character in
            result.append(renderedCharacter(character))
        }
    }

    private static func renderedCharacter(_ character: Character) -> String {
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

    private static func isASCIIPunctuation(_ value: UInt32) -> Bool {
        (33...47).contains(value)
            || (58...64).contains(value)
            || (91...96).contains(value)
            || (123...126).contains(value)
    }
}
