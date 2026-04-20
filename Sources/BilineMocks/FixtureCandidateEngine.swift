import BilineCore
import BilinePreview
import Foundation

private struct FixtureEntry: Codable, Sendable {
    let surface: String
    let reading: String
    let score: Int
    let previewTranslation: String
}

private struct FixtureLexicon: Sendable {
    let candidatesByReading: [String: [Candidate]]
    let previewBySurface: [String: String]
    let syllables: Set<String>
}

private enum FixtureLoader {
    static func load(resourceName: String, bundle: Bundle) throws -> FixtureLexicon {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw NSError(
                domain: "BilineMocks.FixtureLoader",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Missing fixture resource: \(resourceName).json"
                ]
            )
        }

        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([FixtureEntry].self, from: data)

        let grouped = Dictionary(grouping: entries, by: \.reading).mapValues { group in
            group
                .sorted { lhs, rhs in
                    if lhs.score == rhs.score {
                        return lhs.surface < rhs.surface
                    }
                    return lhs.score > rhs.score
                }
                .enumerated()
                .map { index, entry in
                    Candidate(
                        id: "\(entry.reading)#\(index)#\(entry.surface)",
                        surface: entry.surface,
                        reading: entry.reading,
                        score: entry.score,
                        consumedTokenCount: entry.reading.split(separator: " ").count
                    )
                }
        }

        let previewBySurface = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.surface, $0.previewTranslation) }
        )

        let syllables = Set(entries.flatMap { $0.reading.split(separator: " ").map(String.init) })

        return FixtureLexicon(
            candidatesByReading: grouped,
            previewBySurface: previewBySurface,
            syllables: syllables
        )
    }
}

public struct FixtureCandidateEngineFactory: CandidateEngineFactory, Sendable {
    private let lexicon: FixtureLexicon

    public init(resourceName: String = "demo_dictionary") throws {
        try self.init(resourceName: resourceName, bundle: .module)
    }

    public init(resourceName: String, bundle: Bundle) throws {
        self.lexicon = try FixtureLoader.load(resourceName: resourceName, bundle: bundle)
    }

    public static func demo() -> FixtureCandidateEngineFactory {
        do {
            return try FixtureCandidateEngineFactory()
        } catch {
            fatalError("Unable to load demo dictionary: \(error)")
        }
    }

    public func makeSession(config: EngineConfig) -> any CandidateEngineSession {
        FixtureCandidateEngineSession(lexicon: lexicon, config: config)
    }
}

final class FixtureCandidateEngineSession: CandidateEngineSession, @unchecked Sendable {
    private let lexicon: FixtureLexicon
    private let config: EngineConfig

    private var rawInput = ""
    private var allCandidates: [Candidate] = []
    private var selectedGlobalIndex = 0
    private var activeRawInput = ""
    private var remainingRawInput = ""
    private var consumedTokenCount = 0

    fileprivate init(lexicon: FixtureLexicon, config: EngineConfig) {
        self.lexicon = lexicon
        self.config = config
    }

    func updateInput(_ rawInput: String) -> CompositionSnapshot {
        self.rawInput = normalize(rawInput)
        rebuildCandidates()
        return makeSnapshot()
    }

    func moveSelection(_ direction: SelectionDirection) -> CompositionSnapshot {
        guard !allCandidates.isEmpty else {
            return makeSnapshot()
        }

        switch direction {
        case .next:
            selectedGlobalIndex = min(selectedGlobalIndex + 1, allCandidates.count - 1)
        case .previous:
            selectedGlobalIndex = max(selectedGlobalIndex - 1, 0)
        }

        syncSelectionSpan()
        return makeSnapshot()
    }

    func turnPage(_ direction: PageDirection) -> CompositionSnapshot {
        guard !allCandidates.isEmpty else {
            return makeSnapshot()
        }

        let pageCount = Int(ceil(Double(allCandidates.count) / Double(config.pageSize)))
        let currentPage = selectedGlobalIndex / config.pageSize
        let targetPage: Int

        switch direction {
        case .next:
            targetPage = min(currentPage + 1, pageCount - 1)
        case .previous:
            targetPage = max(currentPage - 1, 0)
        }

        selectedGlobalIndex = min(targetPage * config.pageSize, allCandidates.count - 1)
        syncSelectionSpan()
        return makeSnapshot()
    }

    func commitSelected() -> CommitResult {
        let committed = allCandidates[safe: selectedGlobalIndex]?.surface ?? rawInput
        let snapshot = reset()
        return CommitResult(committedText: committed, snapshot: snapshot)
    }

    func reset() -> CompositionSnapshot {
        rawInput = ""
        allCandidates = []
        selectedGlobalIndex = 0
        activeRawInput = ""
        remainingRawInput = ""
        consumedTokenCount = 0
        return .idle
    }

    private func rebuildCandidates() {
        guard !rawInput.isEmpty else {
            allCandidates = []
            selectedGlobalIndex = 0
            activeRawInput = ""
            remainingRawInput = ""
            consumedTokenCount = 0
            return
        }

        guard let tokens = tokenize(rawInput) else {
            allCandidates = []
            selectedGlobalIndex = 0
            activeRawInput = ""
            remainingRawInput = rawInput
            consumedTokenCount = 0
            return
        }

        var mergedCandidates: [Candidate] = []
        for prefixCount in stride(from: tokens.count, through: 1, by: -1) {
            let prefixTokens = Array(tokens.prefix(prefixCount))
            let reading = prefixTokens.joined(separator: " ")
            guard let candidates = lexicon.candidatesByReading[reading], !candidates.isEmpty else {
                continue
            }
            mergedCandidates.append(contentsOf: candidates)
        }

        allCandidates = mergedCandidates
        selectedGlobalIndex = min(selectedGlobalIndex, max(allCandidates.count - 1, 0))

        syncSelectionSpan()
    }

    private func syncSelectionSpan() {
        guard let tokens = tokenize(rawInput),
            let selectedCandidate = allCandidates[safe: selectedGlobalIndex]
        else {
            activeRawInput = ""
            remainingRawInput = rawInput
            consumedTokenCount = 0
            return
        }

        let consumedCount = min(selectedCandidate.consumedTokenCount, tokens.count)
        activeRawInput = Array(tokens.prefix(consumedCount)).joined()
        remainingRawInput = Array(tokens.dropFirst(consumedCount)).joined()
        consumedTokenCount = consumedCount
    }

    private func makeSnapshot() -> CompositionSnapshot {
        guard !rawInput.isEmpty else {
            return .idle
        }

        guard !allCandidates.isEmpty else {
            return CompositionSnapshot(
                rawInput: rawInput,
                markedText: rawInput,
                candidates: [],
                selectedIndex: 0,
                pageIndex: 0,
                isComposing: true,
                activeRawInput: activeRawInput,
                remainingRawInput: remainingRawInput,
                consumedTokenCount: consumedTokenCount
            )
        }

        let pageIndex = selectedGlobalIndex / config.pageSize
        let pageStart = pageIndex * config.pageSize
        let pageEnd = min(pageStart + config.pageSize, allCandidates.count)
        let pageCandidates = Array(allCandidates[pageStart..<pageEnd])
        let selectedIndex = selectedGlobalIndex - pageStart

        return CompositionSnapshot(
            rawInput: rawInput,
            markedText: allCandidates[selectedGlobalIndex].surface,
            candidates: pageCandidates,
            selectedIndex: selectedIndex,
            pageIndex: pageIndex,
            isComposing: true,
            activeRawInput: activeRawInput,
            remainingRawInput: remainingRawInput,
            consumedTokenCount: consumedTokenCount
        )
    }

    private func tokenize(_ rawInput: String) -> [String]? {
        var tokens: [String] = []

        for chunk in rawInput.split(separator: "'", omittingEmptySubsequences: false) {
            guard let chunkTokens = tokenizeChunk(String(chunk)) else {
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
                if lexicon.syllables.contains(candidate) {
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

    private func normalize(_ input: String) -> String {
        var result = ""
        result.reserveCapacity(input.count)

        for scalar in input.unicodeScalars {
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
}

public enum MockTranslationError: Error, Equatable, Sendable {
    case forcedFailure(String)
}

public struct MockTranslationProvider: TranslationProvider, Sendable {
    public let providerIdentifier: String = "mock.fixture"

    private let delay: Duration
    private let failures: Set<String>
    private let translations: [String: String]

    public init(
        delay: Duration = .zero,
        failures: Set<String> = [],
        resourceName: String = "demo_dictionary"
    ) {
        self.init(
            delay: delay,
            failures: failures,
            resourceName: resourceName,
            bundle: .module
        )
    }

    public init(
        delay: Duration,
        failures: Set<String>,
        resourceName: String,
        bundle: Bundle
    ) {
        self.delay = delay
        self.failures = failures
        self.translations =
            (try? FixtureLoader.load(resourceName: resourceName, bundle: bundle))
            .map(\.previewBySurface) ?? [:]
    }

    public func translate(_ text: String, target: TargetLanguage) async throws -> String {
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }

        if failures.contains(text) {
            throw MockTranslationError.forcedFailure(text)
        }

        return translations[text] ?? "[\(target.rawValue)] \(text)"
    }
}

extension Collection {
    fileprivate subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
