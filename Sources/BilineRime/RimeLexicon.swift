import Foundation

struct RimeConsumption: Sendable, Equatable {
    let tokenCount: Int
    let tokens: [String]
}

struct RimeDictionaryEntry: Sendable {
    let surface: String
    let readingTokens: [String]
    let reading: String
    let weight: Int

    init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "---" || trimmed == "..." {
            return nil
        }
        if trimmed.contains(":") && !trimmed.contains("\t") { return nil }

        let fields = trimmed.split(separator: "\t", omittingEmptySubsequences: true).map(
            String.init)
        guard fields.count >= 2 else { return nil }
        let tokens = PinyinTokenizer.normalizePinyin(fields[1], keepsSpaces: true)
            .split(whereSeparator: { $0 == " " || $0 == "'" })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        self.surface = fields[0].applyingRimeLexiconSimplifiedFallbacks()
        self.readingTokens = tokens
        self.reading = tokens.joined(separator: " ")
        self.weight = fields.dropFirst(2).compactMap { Int($0) }.first ?? 0
    }
}

func parseDictionaryEntries(from contents: String) -> [RimeDictionaryEntry] {
    contents
        .split(whereSeparator: \.isNewline)
        .compactMap { RimeDictionaryEntry(line: String($0)) }
}

struct RimeLexicon: Sendable {
    struct Entry: Sendable, Equatable, Hashable {
        let surface: String
        let reading: String
        let readingTokens: [String]
        let weight: Int
    }

    let entriesByReading: [String: [Entry]]
    let entriesBySurface: [String: [Entry]]

    static func fromDictionaryFiles(at urls: [URL]) throws -> RimeLexicon {
        var byReading: [String: [Entry]] = [:]
        var bySurface: [String: [Entry]] = [:]
        var seen = Set<Entry>()

        for url in urls {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let contents = try String(contentsOf: url, encoding: .utf8)
            for line in contents.split(whereSeparator: \.isNewline) {
                guard let record = RimeDictionaryEntry(line: String(line)) else { continue }
                let entry = Entry(
                    surface: record.surface,
                    reading: record.reading,
                    readingTokens: record.readingTokens,
                    weight: record.weight
                )
                guard seen.insert(entry).inserted else { continue }
                byReading[entry.reading, default: []].append(entry)
                bySurface[entry.surface, default: []].append(entry)
            }
        }

        for key in byReading.keys { byReading[key]?.sort(by: Self.entrySort) }
        for key in bySurface.keys { bySurface[key]?.sort(by: Self.entrySort) }
        return RimeLexicon(entriesByReading: byReading, entriesBySurface: bySurface)
    }

    func consumption(
        forSurface surface: String,
        rawInput: String,
        comment: String?,
        tokenizer: PinyinTokenizer
    ) -> RimeConsumption {
        consumption(
            forSurface: surface,
            rawInput: rawInput,
            comment: comment,
            tokenizer: tokenizer,
            tokenizations: tokenizer.tokenizeAll(rawInput)
        )
    }

    /// Variant that accepts pre-computed tokenizations so a hot path that
    /// processes many candidates against the same `rawInput` (e.g. the Rime
    /// candidate-engine snapshot mapper) can tokenize once and reuse the
    /// result for every candidate. `tokenizeAll` runs a recursive DP over
    /// the input, which is non-trivial for typical 5–10 syllable inputs and
    /// gets called per keystroke per candidate (≈ 25 times) without this
    /// overload.
    func consumption(
        forSurface surface: String,
        rawInput: String,
        comment: String?,
        tokenizer: PinyinTokenizer,
        tokenizations: [[String]]
    ) -> RimeConsumption {
        if let commentTokens = tokenizer.readingTokens(from: comment ?? ""), !commentTokens.isEmpty
        {
            for tokens in tokenizations where tokens.count >= commentTokens.count {
                if Array(tokens.prefix(commentTokens.count)) == commentTokens {
                    return RimeConsumption(tokenCount: commentTokens.count, tokens: tokens)
                }
            }
        }

        let normalizedSurface = surface.applyingRimeLexiconSimplifiedFallbacks()
        var best = RimeConsumption(tokenCount: 0, tokens: tokenizations.first ?? [])
        for tokens in tokenizations {
            for prefixCount in stride(from: tokens.count, through: 1, by: -1) {
                let reading = Array(tokens.prefix(prefixCount)).joined(separator: " ")
                let matchesSurface =
                    entriesByReading[reading]?.contains(where: {
                        $0.surface == normalizedSurface
                    }) == true
                if matchesSurface, prefixCount > best.tokenCount {
                    best = RimeConsumption(tokenCount: prefixCount, tokens: tokens)
                    break
                }
            }
        }

        if best.tokenCount > 0 {
            return best
        }

        if let abbreviated = abbreviatedConsumption(
            forSurface: normalizedSurface,
            rawInput: rawInput,
            comment: comment,
            tokenizer: tokenizer
        ) {
            return abbreviated
        }

        return best
    }

    func coverageMap(for rawInput: String, tokenizer: PinyinTokenizer) -> [String: Int] {
        var coverage: [String: Int] = [:]
        for tokens in tokenizer.tokenizeAll(rawInput) {
            for prefixCount in stride(from: tokens.count, through: 1, by: -1) {
                let reading = Array(tokens.prefix(prefixCount)).joined(separator: " ")
                guard let entries = entriesByReading[reading] else { continue }
                for entry in entries {
                    coverage[entry.surface] = max(coverage[entry.surface] ?? 0, prefixCount)
                }
            }
        }
        return coverage
    }

    func consumedTokenCount(
        surface: String,
        comment: String,
        rawInput: String,
        tokenizer: PinyinTokenizer
    ) -> Int {
        consumption(
            forSurface: surface,
            rawInput: rawInput,
            comment: comment.isEmpty ? nil : comment,
            tokenizer: tokenizer
        ).tokenCount
    }

    struct Match: Sendable, Equatable {
        let entry: Entry
        let consumedTokenCount: Int
        let tokens: [String]
    }

    func prefixMatches(for rawInput: String, tokenizer: PinyinTokenizer) -> [Match] {
        var bestBySurface: [String: Match] = [:]
        for tokens in tokenizer.tokenizeAll(rawInput) {
            for prefixCount in stride(from: tokens.count, through: 1, by: -1) {
                let reading = Array(tokens.prefix(prefixCount)).joined(separator: " ")
                guard let entries = entriesByReading[reading] else { continue }
                for entry in entries {
                    let match = Match(entry: entry, consumedTokenCount: prefixCount, tokens: tokens)
                    if let existing = bestBySurface[entry.surface] {
                        if Self.matchSort(match, existing) {
                            bestBySurface[entry.surface] = match
                        }
                    } else {
                        bestBySurface[entry.surface] = match
                    }
                }
            }
        }
        return bestBySurface.values.sorted(by: Self.matchSort)
    }

    private static func matchSort(_ lhs: Match, _ rhs: Match) -> Bool {
        let lhsConsumesWholeInput = lhs.consumedTokenCount == lhs.tokens.count
        let rhsConsumesWholeInput = rhs.consumedTokenCount == rhs.tokens.count
        if lhsConsumesWholeInput != rhsConsumesWholeInput {
            return lhsConsumesWholeInput
        }

        if !lhsConsumesWholeInput, lhs.consumedTokenCount != rhs.consumedTokenCount {
            return lhs.consumedTokenCount < rhs.consumedTokenCount
        }

        if lhs.entry.weight != rhs.entry.weight { return lhs.entry.weight > rhs.entry.weight }
        if lhs.entry.surface.count != rhs.entry.surface.count {
            return lhs.entry.surface.count > rhs.entry.surface.count
        }
        return lhs.entry.surface < rhs.entry.surface
    }

    private static func entrySort(_ lhs: Entry, _ rhs: Entry) -> Bool {
        if lhs.weight != rhs.weight { return lhs.weight > rhs.weight }
        if lhs.readingTokens.count != rhs.readingTokens.count {
            return lhs.readingTokens.count > rhs.readingTokens.count
        }
        if lhs.surface.count != rhs.surface.count { return lhs.surface.count > rhs.surface.count }
        return lhs.surface < rhs.surface
    }

    private func abbreviatedConsumption(
        forSurface normalizedSurface: String,
        rawInput: String,
        comment: String?,
        tokenizer: PinyinTokenizer
    ) -> RimeConsumption? {
        let readingOptions = candidateReadingOptions(
            forSurface: normalizedSurface,
            comment: comment,
            tokenizer: tokenizer
        )
        guard !readingOptions.isEmpty else { return nil }

        var best: RimeConsumption?
        for readingTokens in readingOptions {
            guard
                let rawTokens = rawTokensMatching(
                    readingTokens: readingTokens,
                    rawInput: rawInput,
                    tokenizer: tokenizer
                )
            else {
                continue
            }
            let consumption = RimeConsumption(tokenCount: readingTokens.count, tokens: rawTokens)
            guard let currentBest = best else {
                best = consumption
                continue
            }
            if consumption.tokenCount > currentBest.tokenCount
                || (consumption.tokenCount == currentBest.tokenCount
                    && consumption.tokens.count < currentBest.tokens.count)
            {
                best = consumption
            }
        }
        return best
    }

    private func candidateReadingOptions(
        forSurface normalizedSurface: String,
        comment: String?,
        tokenizer: PinyinTokenizer
    ) -> [[String]] {
        var options: [[String]] = []
        var seen = Set<[String]>()

        func append(_ tokens: [String]) {
            guard !tokens.isEmpty, seen.insert(tokens).inserted else { return }
            options.append(tokens)
        }

        if let commentTokens = tokenizer.readingTokens(from: comment ?? "") {
            append(commentTokens)
        }

        for entry in entriesBySurface[normalizedSurface] ?? [] {
            append(entry.readingTokens)
        }

        return options
    }

    private func rawTokensMatching(
        readingTokens: [String],
        rawInput: String,
        tokenizer: PinyinTokenizer
    ) -> [String]? {
        let normalizedInput = PinyinTokenizer.normalizeInput(rawInput)
        guard !normalizedInput.isEmpty else { return nil }

        var rawTokens: [String] = []
        var cursor = normalizedInput.startIndex
        for readingToken in readingTokens {
            guard cursor < normalizedInput.endIndex,
                let firstReadingScalar = readingToken.unicodeScalars.first
            else {
                return nil
            }

            let remaining = normalizedInput[cursor...]
            if remaining.hasPrefix(readingToken) {
                rawTokens.append(readingToken)
                cursor = normalizedInput.index(cursor, offsetBy: readingToken.count)
                continue
            }

            let firstRawScalar = normalizedInput[cursor].unicodeScalars.first
            guard firstRawScalar == firstReadingScalar else {
                return nil
            }

            rawTokens.append(String(normalizedInput[cursor]))
            cursor = normalizedInput.index(after: cursor)
        }

        if cursor < normalizedInput.endIndex {
            let remainingRawInput = String(normalizedInput[cursor...])
            rawTokens.append(
                contentsOf: fallbackTokens(for: remainingRawInput, tokenizer: tokenizer))
        }

        return rawTokens
    }

    private func fallbackTokens(for rawInput: String, tokenizer: PinyinTokenizer) -> [String] {
        if let tokens = tokenizer.tokenize(rawInput) {
            return tokens
        }
        return rawInput.map(String.init)
    }
}
