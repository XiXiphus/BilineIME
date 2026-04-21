import BilineCore
import BilinePreview
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

    public static func appDefault(settingsStore: any SettingsStore) throws
        -> BilinePinyinEngineFactory
    {
        try BilinePinyinEngineFactory(
            fuzzyPinyinEnabled: settingsStore.fuzzyPinyinEnabled,
            characterForm: settingsStore.characterForm
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

private enum PinyinResourceLocator {
    struct ResourceURLs {
        let tokenizerSeed: URL
        let lexiconFiles: [URL]
    }

    static func dictionaryURLs() throws -> ResourceURLs {
        let candidates = [
            repoVendorFile("rime-luna-pinyin/luna_pinyin.dict.yaml"),
            bundleResource("luna_pinyin.dict", ext: "yaml", subdirectory: nil),
            bundleResource("luna_pinyin.dict", ext: "yaml", subdirectory: "RimeTemplates"),
        ].compactMap { $0 }

        guard
            let tokenizerSeed = candidates.first(where: {
                FileManager.default.fileExists(atPath: $0.path)
            })
        else {
            throw RimeError.missingResource("luna_pinyin.dict.yaml")
        }

        let lexiconFiles = [
            tokenizerSeed,
            bundleResource("biline_phrases.dict", ext: "yaml", subdirectory: "RimeTemplates"),
            bundleResource(
                "biline_modern_phrases.dict", ext: "yaml", subdirectory: "RimeTemplates"),
            repoResource("Sources/BilineRime/Resources/RimeTemplates/biline_phrases.dict.yaml"),
            repoResource(
                "Sources/BilineRime/Resources/RimeTemplates/biline_modern_phrases.dict.yaml"),
        ].compactMap { $0 }.filter { FileManager.default.fileExists(atPath: $0.path) }

        return ResourceURLs(tokenizerSeed: tokenizerSeed, lexiconFiles: lexiconFiles)
    }

    private static func bundleResource(_ name: String, ext: String, subdirectory: String?) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
            ?? Bundle.module.url(forResource: name, withExtension: ext)
    }

    private static func repoResource(_ relativePath: String) -> URL? {
        let url = repoRoot().appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func repoVendorFile(_ relativePath: String) -> URL? {
        repoResource("Vendor/\(relativePath)")
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

extension String {
    fileprivate func applyingCommonSimplifiedFallbacks() -> String {
        let table: [Character: String] = [
            "學": "学", "習": "习", "國": "国", "語": "语", "電": "电", "腦": "脑", "網": "网", "絡": "络",
            "軟": "软", "體": "体", "開": "开", "發": "发", "數": "数", "據": "据", "庫": "库", "雲": "云",
            "臺": "台", "台": "台", "後": "后", "裏": "里", "裡": "里", "麼": "么", "為": "为", "與": "与",
            "這": "这", "個": "个", "們": "们", "會": "会", "來": "来", "時": "时", "間": "间", "現": "现",
            "讓": "让", "對": "对", "應": "应", "問": "问", "題": "题", "無": "无", "線": "线", "測": "测",
            "試": "试", "設": "设", "計": "计", "產": "产", "業": "业", "機": "机", "器": "器",
        ]
        return reduce(into: "") { result, character in
            result.append(table[character] ?? String(character))
        }
    }
}
