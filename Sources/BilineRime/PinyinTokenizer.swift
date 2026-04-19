import Foundation

struct PinyinTokenizer: Sendable {
    let syllables: Set<String>

    init(syllables: Set<String>) {
        self.syllables = syllables
    }

    static func fromDictionaryFile(at url: URL) throws -> PinyinTokenizer {
        let contents = try String(contentsOf: url, encoding: .utf8)
        var syllables = Set<String>()

        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "---" || trimmed == "..." {
                continue
            }
            if trimmed.contains(":") && !trimmed.contains("\t") {
                continue
            }

            let fields = trimmed.split(separator: "\t", omittingEmptySubsequences: true)
            guard fields.count >= 2 else { continue }
            for token in fields[1].split(separator: " ", omittingEmptySubsequences: true) {
                syllables.insert(String(token))
            }
        }

        return PinyinTokenizer(syllables: syllables)
    }

    func tokenize(_ input: String) -> [String]? {
        let parts = input.split(separator: "'", omittingEmptySubsequences: false)
        var tokens: [String] = []

        for part in parts {
            let chunk = String(part)
            guard let chunkTokens = tokenizeChunk(chunk) else {
                return nil
            }
            tokens.append(contentsOf: chunkTokens)
        }

        return tokens
    }

    private func tokenizeChunk(_ chunk: String) -> [String]? {
        guard !chunk.isEmpty else {
            return []
        }

        var tokens: [String] = []
        var cursor = chunk.startIndex

        while cursor < chunk.endIndex {
            var matched: String?
            var probe = chunk.endIndex

            while probe > cursor {
                let candidate = String(chunk[cursor..<probe])
                if syllables.contains(candidate) {
                    matched = candidate
                    break
                }
                probe = chunk.index(before: probe)
            }

            guard let matched else {
                return nil
            }

            tokens.append(matched)
            cursor = chunk.index(cursor, offsetBy: matched.count)
        }

        return tokens
    }
}

struct RimeLexicon: Sendable {
    let candidatesByReading: [String: Set<String>]

    static func fromDictionaryFiles(at urls: [URL]) throws -> RimeLexicon {
        var storage: [String: Set<String>] = [:]

        for url in urls {
            let contents = try String(contentsOf: url, encoding: .utf8)
            for line in contents.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "---" || trimmed == "..." {
                    continue
                }
                if trimmed.contains(":") && !trimmed.contains("\t") {
                    continue
                }

                let fields = trimmed.split(separator: "\t", omittingEmptySubsequences: true)
                guard fields.count >= 2 else { continue }
                let surface = String(fields[0])
                let reading = String(fields[1])
                storage[reading, default: []].insert(surface)
            }
        }

        return RimeLexicon(candidatesByReading: storage)
    }

    func coverageMap(for rawInput: String, tokenizer: PinyinTokenizer) -> [String: Int] {
        guard let tokens = tokenizer.tokenize(rawInput), !tokens.isEmpty else {
            return [:]
        }

        var coverage: [String: Int] = [:]
        for prefixCount in stride(from: tokens.count, through: 1, by: -1) {
            let reading = Array(tokens.prefix(prefixCount)).joined(separator: " ")
            guard let surfaces = candidatesByReading[reading] else { continue }
            for surface in surfaces {
                coverage[surface] = max(coverage[surface] ?? 0, prefixCount)
            }
        }
        return coverage
    }
}
