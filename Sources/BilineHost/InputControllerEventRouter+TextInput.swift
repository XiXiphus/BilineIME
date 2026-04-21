import Foundation

extension InputControllerEventRouter {
    func pinyinInput(from text: String) -> String {
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

    func candidateColumnIndex(
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

    func actualCharacter(for event: InputControllerEvent) -> String? {
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
