import BilineCore
import Foundation

public struct BilinePinyinEngineFactory: CandidateEngineFactory, Sendable {
    private let backend: RimeCandidateEngineFactory

    public init(
        fuzzyPinyinEnabled: Bool,
        characterForm: CharacterForm
    ) throws {
        self.backend = try RimeCandidateEngineFactory(
            fuzzyPinyinEnabled: fuzzyPinyinEnabled,
            characterForm: characterForm
        )
    }

    public func makeSession(config: EngineConfig) -> any CandidateEngineSession {
        backend.makeSession(config: config)
    }
}

struct DictionaryPinyinCandidateEngineFactory: CandidateEngineFactory, Sendable {
    private let tokenizer: PinyinTokenizer
    private let lexicon: RimeLexicon
    private let characterForm: CharacterForm

    init(characterForm: CharacterForm) throws {
        let resourceURLs = try PinyinResourceLocator.dictionaryURLs()
        self.tokenizer = try PinyinTokenizer.fromDictionaryFile(at: resourceURLs.tokenizerSeed)
        self.lexicon = try RimeLexicon.fromDictionaryFiles(at: resourceURLs.lexiconFiles)
        self.characterForm = characterForm
    }

    func makeSession(config: EngineConfig) -> any CandidateEngineSession {
        DictionaryPinyinCandidateEngineSession(
            tokenizer: tokenizer,
            lexicon: lexicon,
            config: config,
            characterForm: characterForm
        )
    }
}

private struct DictionaryCandidate: Sendable, Equatable {
    let candidate: Candidate
    let tokens: [String]
}

private final class DictionaryPinyinCandidateEngineSession: CandidateEngineSession,
    @unchecked Sendable
{
    private let tokenizer: PinyinTokenizer
    private let lexicon: RimeLexicon
    private let pageSize: Int
    private let characterForm: CharacterForm

    private var rawInput = ""
    private var allCandidates: [DictionaryCandidate] = []
    private var selectedGlobalIndex = 0
    private var pageIndex = 0

    init(
        tokenizer: PinyinTokenizer,
        lexicon: RimeLexicon,
        config: EngineConfig,
        characterForm: CharacterForm
    ) {
        self.tokenizer = tokenizer
        self.lexicon = lexicon
        self.pageSize = max(1, config.pageSize)
        self.characterForm = characterForm
    }

    func updateInput(_ rawInput: String) -> CompositionSnapshot {
        let normalized = normalize(rawInput)
        guard !normalized.isEmpty else {
            return reset()
        }

        self.rawInput = normalized
        pageIndex = 0
        selectedGlobalIndex = 0
        allCandidates = makeCandidates(for: normalized)
        return snapshot()
    }

    func moveSelection(_ direction: SelectionDirection) -> CompositionSnapshot {
        guard !allCandidates.isEmpty else { return snapshot() }

        switch direction {
        case .next:
            selectedGlobalIndex = min(allCandidates.count - 1, selectedGlobalIndex + 1)
        case .previous:
            selectedGlobalIndex = max(0, selectedGlobalIndex - 1)
        }
        pageIndex = selectedGlobalIndex / pageSize
        return snapshot()
    }

    func turnPage(_ direction: PageDirection) -> CompositionSnapshot {
        guard !allCandidates.isEmpty else { return snapshot() }
        let pageCount = max(1, Int(ceil(Double(allCandidates.count) / Double(pageSize))))

        switch direction {
        case .next:
            pageIndex = min(pageCount - 1, pageIndex + 1)
        case .previous:
            pageIndex = max(0, pageIndex - 1)
        }
        selectedGlobalIndex = min(pageIndex * pageSize, allCandidates.count - 1)
        return snapshot()
    }

    func commitSelected() -> CommitResult {
        guard !allCandidates.isEmpty else {
            let committed = rawInput
            _ = reset()
            return CommitResult(committedText: committed, snapshot: .idle)
        }

        let selected = allCandidates[selectedGlobalIndex]
        let committed = selected.candidate.surface
        let totalTokenCount = selected.tokens.count
        let consumedTokenCount = selected.candidate.consumedTokenCount
        let tailInput =
            consumedTokenCount > 0 && consumedTokenCount < totalTokenCount
            ? Array(selected.tokens.dropFirst(consumedTokenCount)).joined()
            : ""

        if tailInput.isEmpty {
            _ = reset()
            return CommitResult(committedText: committed, snapshot: .idle)
        }

        let nextSnapshot = updateInput(tailInput)
        return CommitResult(committedText: committed, snapshot: nextSnapshot)
    }

    func reset() -> CompositionSnapshot {
        rawInput = ""
        allCandidates = []
        selectedGlobalIndex = 0
        pageIndex = 0
        return .idle
    }

    private func makeCandidates(for rawInput: String) -> [DictionaryCandidate] {
        let matches = lexicon.prefixMatches(for: rawInput, tokenizer: tokenizer)
        guard !matches.isEmpty else { return [] }

        return matches.enumerated().map { offset, match in
            DictionaryCandidate(
                candidate: Candidate(
                    id: "dict:\(rawInput):\(offset):\(match.entry.surface)",
                    surface: renderedSurface(match.entry.surface),
                    reading: rawInput,
                    score: max(0, matches.count - offset + match.entry.weight),
                    consumedTokenCount: match.consumedTokenCount
                ),
                tokens: match.tokens
            )
        }
    }

    private func snapshot() -> CompositionSnapshot {
        guard !rawInput.isEmpty else { return .idle }
        guard !allCandidates.isEmpty else {
            return CompositionSnapshot(
                rawInput: rawInput,
                markedText: rawInput,
                candidates: [],
                selectedIndex: 0,
                pageIndex: 0,
                isComposing: true,
                activeRawInput: "",
                remainingRawInput: rawInput,
                consumedTokenCount: 0
            )
        }

        let pageStart = pageIndex * pageSize
        let pageEnd = min(pageStart + pageSize, allCandidates.count)
        let pageRecords = Array(allCandidates[pageStart..<pageEnd])
        let pageCandidates = pageRecords.map(\.candidate)
        let localSelectedIndex = max(
            0, min(selectedGlobalIndex - pageStart, pageCandidates.count - 1))
        let selectedConsumedCount = pageRecords[localSelectedIndex].candidate.consumedTokenCount
        let tokens = pageRecords[localSelectedIndex].tokens
        let activeRawInput =
            selectedConsumedCount > 0 ? Array(tokens.prefix(selectedConsumedCount)).joined() : ""
        let remainingRawInput =
            selectedConsumedCount > 0
            ? Array(tokens.dropFirst(selectedConsumedCount)).joined()
            : rawInput

        return CompositionSnapshot(
            rawInput: rawInput,
            markedText: rawInput,
            candidates: pageCandidates,
            selectedIndex: localSelectedIndex,
            pageIndex: pageIndex,
            isComposing: true,
            activeRawInput: activeRawInput,
            remainingRawInput: remainingRawInput,
            consumedTokenCount: selectedConsumedCount
        )
    }

    private func normalize(_ input: String) -> String {
        PinyinTokenizer.normalizeInput(input)
    }

    private func renderedSurface(_ surface: String) -> String {
        switch characterForm {
        case .simplified:
            return surface.applyingCommonSimplifiedFallbacks()
        case .traditional:
            return surface
        }
    }
}
