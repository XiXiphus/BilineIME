import BilineCore
import BilinePreview
import CBilineRime
import Foundation

private let rimeBackspaceKeycode: Int32 = 0xff08

public struct RimeCandidateEngineFactory: CandidateEngineFactory, Sendable {
    private let settings: RimeSettings
    private let tokenizer: PinyinTokenizer
    private let lexicon: RimeLexicon
    private let schemaID = "biline_pinyin"

    public init(
        fuzzyPinyinEnabled: Bool,
        characterForm: CharacterForm
    ) throws {
        let settings = RimeSettings(
            pageSize: 25,
            fuzzyPinyinEnabled: fuzzyPinyinEnabled,
            characterForm: characterForm
        )
        self.settings = settings
        let runtime = RimeRuntime.shared
        self.tokenizer = try runtime.makeTokenizer(settings: settings)
        self.lexicon = try runtime.makeLexicon(settings: settings)
    }

    public static func appDefault(settingsStore: any SettingsStore) throws -> RimeCandidateEngineFactory {
        try RimeCandidateEngineFactory(
            fuzzyPinyinEnabled: settingsStore.fuzzyPinyinEnabled,
            characterForm: settingsStore.characterForm
        )
    }

    public func makeSession(config: EngineConfig) -> any CandidateEngineSession {
        do {
            return try RimeCandidateEngineSession(
                schemaID: schemaID,
                settings: RimeSettings(
                    pageSize: config.pageSize,
                    fuzzyPinyinEnabled: settings.fuzzyPinyinEnabled,
                    characterForm: settings.characterForm
                ),
                tokenizer: tokenizer,
                lexicon: lexicon
            )
        } catch {
            fatalError("Unable to create Rime engine session: \(error)")
        }
    }
}

final class RimeCandidateEngineSession: CandidateEngineSession, @unchecked Sendable {
    private let schemaID: String
    private let settings: RimeSettings
    private let tokenizer: PinyinTokenizer
    private let lexicon: RimeLexicon
    private let runtime = RimeRuntime.shared

    private var sessionID: BRimeSessionId
    private var rawInput = ""

    init(
        schemaID: String,
        settings: RimeSettings,
        tokenizer: PinyinTokenizer,
        lexicon: RimeLexicon
    ) throws {
        self.schemaID = schemaID
        self.settings = settings
        self.tokenizer = tokenizer
        self.lexicon = lexicon
        self.sessionID = try runtime.makeSession(schemaID: schemaID, settings: settings)
    }

    deinit {
        _ = BRimeDestroySession(sessionID)
    }

    func updateInput(_ rawInput: String) -> CompositionSnapshot {
        let normalizedInput = normalize(rawInput)
        guard !normalizedInput.isEmpty else {
            self.rawInput = ""
            return .idle
        }

        if normalizedInput != self.rawInput {
            if !applyInputTransition(from: self.rawInput, to: normalizedInput) {
                do {
                    sessionID = try runtime.resetSession(sessionID, schemaID: schemaID, settings: settings)
                } catch {
                    self.rawInput = normalizedInput
                    return rawBufferSnapshot(for: normalizedInput)
                }
                guard replayInput(normalizedInput) else {
                    self.rawInput = normalizedInput
                    return rawBufferSnapshot(for: normalizedInput)
                }
            }
        }

        self.rawInput = normalizedInput
        return makeSnapshot(rawInput: normalizedInput)
    }

    func moveSelection(_ direction: SelectionDirection) -> CompositionSnapshot {
        let current = fetchSnapshot()
        guard current.candidateCount > 0 else {
            return makeSnapshot(rawInput: rawInput)
        }

        let currentIndex = max(0, current.highlightedIndex)
        let targetIndex = direction == .next ? currentIndex + 1 : currentIndex - 1

        if targetIndex >= 0, targetIndex < current.candidateCount {
            _ = BRimeHighlightCandidateOnCurrentPage(sessionID, numericCast(targetIndex))
            return makeSnapshot(rawInput: rawInput)
        }

        let didChangePage = BRimeChangePage(sessionID, direction == .previous)
        guard didChangePage else {
            return makeSnapshot(rawInput: rawInput)
        }

        let newPage = fetchSnapshot()
        guard newPage.candidateCount > 0 else {
            return makeSnapshot(rawInput: rawInput)
        }

        let edgeIndex = direction == .next ? 0 : max(0, newPage.candidateCount - 1)
        _ = BRimeHighlightCandidateOnCurrentPage(sessionID, numericCast(edgeIndex))
        return makeSnapshot(rawInput: rawInput)
    }

    func turnPage(_ direction: PageDirection) -> CompositionSnapshot {
        guard BRimeChangePage(sessionID, direction == .previous) else {
            return makeSnapshot(rawInput: rawInput)
        }
        return makeSnapshot(rawInput: rawInput)
    }

    func commitSelected() -> CommitResult {
        let currentEngineSnapshot = makeSnapshot(rawInput: rawInput)
        guard !currentEngineSnapshot.candidates.isEmpty else {
            return CommitResult(committedText: rawInput, snapshot: .idle)
        }

        var currentSnapshot = fetchSnapshot()
        let selectedIndex = max(0, min(Int(currentSnapshot.highlightedIndex), max(Int(currentSnapshot.candidateCount) - 1, 0)))
        let selectedSurface = currentSnapshot.candidates.map { pointer in
            String(cString: pointer[selectedIndex].text)
        } ?? rawInput
        BRimeFreeSnapshot(&currentSnapshot)

        var result = BRimeCommitResult()
        guard BRimeSelectCandidateOnCurrentPage(sessionID, numericCast(selectedIndex), &result) else {
            return CommitResult(committedText: rawInput, snapshot: .idle)
        }
        defer { BRimeFreeCommitResult(&result) }

        let committedText = result.committedText.map { String(cString: $0) }
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? selectedSurface

        let totalTokenCount = tokenizer.tokenize(rawInput)?.count ?? 0
        let selectedConsumedCount = currentEngineSnapshot.consumedTokenCount
        let fallbackTailInput = selectedConsumedCount > 0 && selectedConsumedCount < totalTokenCount
            ? currentEngineSnapshot.remainingRawInput
            : ""

        let postCommitInput = result.postCommitSnapshot.input.map { String(cString: $0) } ?? ""
        let shouldUseFallbackTail =
            !fallbackTailInput.isEmpty
            && (postCommitInput.isEmpty || postCommitInput == rawInput)

        let snapshot: CompositionSnapshot
        if shouldUseFallbackTail {
            rawInput = fallbackTailInput
            do {
                sessionID = try runtime.resetSession(sessionID, schemaID: schemaID, settings: settings)
                guard replayInput(fallbackTailInput) else {
                    snapshot = rawBufferSnapshot(for: fallbackTailInput)
                    return CommitResult(committedText: committedText, snapshot: snapshot)
                }
                snapshot = makeSnapshot(rawInput: fallbackTailInput)
            } catch {
                snapshot = rawBufferSnapshot(for: fallbackTailInput)
            }
        } else if postCommitInput.isEmpty && !result.postCommitSnapshot.isComposing {
            rawInput = ""
            snapshot = .idle
        } else {
            rawInput = postCommitInput
            snapshot = mapSnapshot(result.postCommitSnapshot, rawInput: postCommitInput)
        }

        return CommitResult(committedText: committedText, snapshot: snapshot)
    }

    func reset() -> CompositionSnapshot {
        rawInput = ""
        do {
            sessionID = try runtime.resetSession(sessionID, schemaID: schemaID, settings: settings)
        } catch {
            _ = BRimeDestroySession(sessionID)
            sessionID = 0
        }
        return .idle
    }

    private func makeSnapshot(rawInput: String) -> CompositionSnapshot {
        var snapshot = fetchSnapshot()
        defer { BRimeFreeSnapshot(&snapshot) }
        return mapSnapshot(snapshot, rawInput: rawInput)
    }

    private func fetchSnapshot() -> BRimeSnapshot {
        var snapshot = BRimeSnapshot()
        if !BRimeGetSnapshot(sessionID, &snapshot) {
            return BRimeSnapshot()
        }
        return snapshot
    }

    private func mapSnapshot(_ snapshot: BRimeSnapshot, rawInput: String) -> CompositionSnapshot {
        guard !rawInput.isEmpty else {
            return .idle
        }

        let candidateCount = Int(snapshot.candidateCount)
        let selectedIndex = max(0, min(Int(snapshot.highlightedIndex), max(candidateCount - 1, 0)))
        let coverage = lexicon.coverageMap(for: rawInput, tokenizer: tokenizer)

        var candidates: [Candidate] = []
        if let basePointer = snapshot.candidates {
            for index in 0..<candidateCount {
                let candidate = basePointer[index]
                let text = candidate.text.map { String(cString: $0) } ?? ""
                let consumedTokenCount = coverage[text] ?? 0
                candidates.append(
                    Candidate(
                        id: "rime:\(snapshot.pageNo):\(index):\(text)",
                        surface: text,
                        reading: rawInput,
                        score: max(0, candidateCount - index),
                        consumedTokenCount: consumedTokenCount
                    )
                )
            }
        }

        if candidates.isEmpty {
            return rawBufferSnapshot(for: rawInput)
        }

        let selectedConsumed = candidates[selectedIndex].consumedTokenCount
        let tokens = tokenizer.tokenize(rawInput) ?? []
        let activeRawInput = selectedConsumed > 0 ? Array(tokens.prefix(selectedConsumed)).joined() : ""
        let remainingRawInput = selectedConsumed > 0 ? Array(tokens.dropFirst(selectedConsumed)).joined() : rawInput

        return CompositionSnapshot(
            rawInput: rawInput,
            markedText: rawInput,
            candidates: candidates,
            selectedIndex: selectedIndex,
            pageIndex: Int(snapshot.pageNo),
            isComposing: true,
            activeRawInput: activeRawInput,
            remainingRawInput: remainingRawInput,
            consumedTokenCount: selectedConsumed
        )
    }

    private func rawBufferSnapshot(for rawInput: String) -> CompositionSnapshot {
        CompositionSnapshot(
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

    private func normalize(_ input: String) -> String {
        input
            .lowercased()
            .filter { $0.isLetter || $0 == "'" }
    }

    private func applyInputTransition(from previousInput: String, to nextInput: String) -> Bool {
        if previousInput.isEmpty {
            return replayInput(nextInput)
        }

        if nextInput.hasPrefix(previousInput) {
            let suffix = nextInput.dropFirst(previousInput.count)
            return processCharacters(suffix)
        }

        if previousInput.hasPrefix(nextInput) {
            let deleteCount = previousInput.count - nextInput.count
            for _ in 0..<deleteCount {
                guard BRimeProcessKey(sessionID, rimeBackspaceKeycode, 0) else {
                    return false
                }
            }
            return true
        }

        return false
    }

    private func replayInput(_ input: String) -> Bool {
        processCharacters(input[...])
    }

    private func processCharacters<S: Sequence>(_ characters: S) -> Bool where S.Element == Character {
        for character in characters {
            guard let keycode = keycode(for: character) else {
                return false
            }
            guard BRimeProcessKey(sessionID, keycode, 0) else {
                return false
            }
        }
        return true
    }

    private func keycode(for character: Character) -> Int32? {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return nil
        }
        guard scalar.isASCII else {
            return nil
        }
        return Int32(scalar.value)
    }
}
