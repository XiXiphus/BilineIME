import BilineCore
import Foundation

extension InputControllerEventRouter {
    func terminatingPunctuationCommitText(from event: InputControllerEvent) -> String? {
        let candidates = [event.characters, event.charactersIgnoringModifiers].compactMap { $0 }
        let terminatingPunctuation: Set<String> = [",", ".", "!", "?", ";", ":"]

        for candidate in candidates where candidate.count == 1 {
            if terminatingPunctuation.contains(candidate) {
                return candidate
            }
        }

        return nil
    }

    func standalonePunctuationText(
        from event: InputControllerEvent,
        state: InputControllerState
    ) -> String? {
        guard let character = actualCharacter(for: event),
            PunctuationPolicy.canHandle(character)
        else {
            return nil
        }
        return PunctuationPolicy.renderCommittedText(character, form: state.punctuationForm)
    }

    func literalAppendAction(
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
}
