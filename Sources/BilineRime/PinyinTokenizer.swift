import BilineCore
import Foundation

struct PinyinTokenizer: Sendable {
    let syllables: Set<String>
    private let segmenter: PinyinInputSegmenter

    init(syllables: Set<String>) {
        let segmenter = PinyinInputSegmenter(syllables: syllables)
        self.segmenter = segmenter
        self.syllables = segmenter.syllables
    }

    static func fromDictionaryFile(at url: URL) throws -> PinyinTokenizer {
        let contents = try String(contentsOf: url, encoding: .utf8)
        var syllables = Set<String>()

        for entry in parseDictionaryEntries(from: contents) {
            for token in entry.readingTokens {
                syllables.insert(token)
            }
        }

        return PinyinTokenizer(syllables: syllables)
    }

    func tokenize(_ input: String) -> [String]? {
        tokenizeAll(input, limit: 1).first
    }

    func tokenizeAll(_ input: String, limit: Int = 128) -> [[String]] {
        segmenter.tokenizeAll(input, limit: limit)
    }

    func readingTokens(from text: String) -> [String]? {
        let normalized = Self.normalizePinyin(text, keepsSpaces: true)
        guard !normalized.isEmpty else { return [] }
        let explicitTokens =
            normalized
            .split(whereSeparator: { $0 == " " || $0 == "'" })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !explicitTokens.isEmpty else { return [] }
        if explicitTokens.allSatisfy({ syllables.contains($0) }) {
            return explicitTokens
        }

        return tokenize(normalized.replacingOccurrences(of: " ", with: "'"))
    }

    static func normalizeInput(_ input: String) -> String {
        PinyinInputSegmenter.normalizeInput(input)
    }

    static func normalizePinyin(_ text: String, keepsSpaces: Bool) -> String {
        PinyinInputSegmenter.normalizePinyin(text, keepsSpaces: keepsSpaces)
    }
}
