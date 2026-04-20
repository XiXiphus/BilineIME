import Cocoa
import CoreText

struct SystemFallbackFontResolver {
    struct Run: Equatable {
        let range: NSRange
        let font: NSFont
        let usesFallback: Bool
    }

    func runs(for text: String, baseFont: NSFont) -> [Run] {
        var runs: [Run] = []
        var utf16Offset = 0

        for character in text {
            let characterText = String(character)
            let length = characterText.utf16.count
            let font = resolvedFont(for: characterText, baseFont: baseFont)
            runs.append(
                Run(
                    range: NSRange(location: utf16Offset, length: length),
                    font: font,
                    usesFallback: font.fontName != baseFont.fontName
                )
            )
            utf16Offset += length
        }

        return coalesced(runs)
    }

    func diagnostics(for text: String, baseFont: NSFont) -> String {
        text.map { character in
            let characterText = String(character)
            let scalars = characterText.unicodeScalars
                .map { String(format: "U+%04X", $0.value) }
                .joined(separator: "+")
            let font = resolvedFont(for: characterText, baseFont: baseFont)
            let fallback = font.fontName == baseFont.fontName ? "base" : "fallback:\(font.fontName)"
            return "\(characterText){\(scalars),\(fallback)}"
        }
        .joined(separator: "")
    }

    private func resolvedFont(for text: String, baseFont: NSFont) -> NSFont {
        let ctBaseFont = baseFont as CTFont
        let range = CFRange(location: 0, length: (text as NSString).length)
        let fallback = CTFontCreateForString(ctBaseFont, text as CFString, range)
        return fallback as NSFont
    }

    private func coalesced(_ runs: [Run]) -> [Run] {
        var result: [Run] = []
        for run in runs {
            guard let last = result.last,
                last.font.fontName == run.font.fontName,
                last.usesFallback == run.usesFallback,
                last.range.location + last.range.length == run.range.location
            else {
                result.append(run)
                continue
            }
            result[result.count - 1] = Run(
                range: NSRange(location: last.range.location, length: last.range.length + run.range.length),
                font: last.font,
                usesFallback: last.usesFallback
            )
        }
        return result
    }
}
