import BilineCore
import CBilineRime
import Foundation

private let rimeBackspaceKeycode: Int32 = 0xff08

final class RimeCandidateEngineSession: CandidateEngineSession, @unchecked Sendable {
    private let schemaID: String
    private let settings: RimeSettings
    private let tokenizer: PinyinTokenizer
    private let lexicon: RimeLexicon
    private let runtime = RimeRuntime.shared

    private var sessionID: BRimeSessionId
    private var rawInput = ""
    private var requiresSessionReset = false

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

        if requiresSessionReset {
            do {
                sessionID = try runtime.resetSession(
                    sessionID, schemaID: schemaID, settings: settings)
                requiresSessionReset = false
            } catch {
                self.rawInput = normalizedInput
                return rawBufferSnapshot(for: normalizedInput)
            }
        }

        if normalizedInput != self.rawInput {
            if !applyInputTransition(from: self.rawInput, to: normalizedInput) {
                do {
                    sessionID = try runtime.resetSession(
                        sessionID, schemaID: schemaID, settings: settings)
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
        let selectedIndex = max(
            0,
            min(
                Int(currentSnapshot.highlightedIndex),
                max(Int(currentSnapshot.candidateCount) - 1, 0)))
        let selectedSurface =
            currentSnapshot.candidates.map { pointer in
                String(cString: pointer[selectedIndex].text)
            } ?? rawInput
        BRimeFreeSnapshot(&currentSnapshot)

        var result = BRimeCommitResult()
        guard BRimeSelectCandidateOnCurrentPage(sessionID, numericCast(selectedIndex), &result)
        else {
            return CommitResult(committedText: rawInput, snapshot: .idle)
        }
        defer { BRimeFreeCommitResult(&result) }

        let committedText =
            result.committedText.map { String(cString: $0) }
            .flatMap { $0.isEmpty ? nil : $0 }
            .map(renderedSurface)
            ?? renderedSurface(selectedSurface)

        let selectedConsumedCount = currentEngineSnapshot.consumedTokenCount
        let selectedConsumesWholeInput =
            selectedConsumedCount > 0 && currentEngineSnapshot.remainingRawInput.isEmpty
        let couldNotProvePrefix = selectedConsumedCount == 0
        let fallbackTailInput =
            selectedConsumedCount > 0 ? currentEngineSnapshot.remainingRawInput : ""

        let postCommitInput = result.postCommitSnapshot.input.map { String(cString: $0) } ?? ""
        let stalePostCommitInput = postCommitInput.isEmpty || postCommitInput == rawInput
        let shouldUseFallbackTail =
            !fallbackTailInput.isEmpty
            && stalePostCommitInput

        let snapshot: CompositionSnapshot
        if selectedConsumesWholeInput || (couldNotProvePrefix && stalePostCommitInput) {
            rawInput = ""
            do {
                sessionID = try runtime.resetSession(
                    sessionID, schemaID: schemaID, settings: settings)
                requiresSessionReset = false
            } catch {
                requiresSessionReset = true
            }
            snapshot = .idle
        } else if shouldUseFallbackTail {
            rawInput = fallbackTailInput
            do {
                sessionID = try runtime.resetSession(
                    sessionID, schemaID: schemaID, settings: settings)
                requiresSessionReset = false
                guard replayInput(fallbackTailInput) else {
                    snapshot = rawBufferSnapshot(for: fallbackTailInput)
                    return CommitResult(committedText: committedText, snapshot: snapshot)
                }
                snapshot = makeSnapshot(rawInput: fallbackTailInput)
            } catch {
                requiresSessionReset = true
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
        requiresSessionReset = false
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
        let preeditText =
            snapshot.preedit.map { String(cString: $0) }
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? rawInput

        var candidates: [Candidate] = []
        var consumptions: [RimeConsumption] = []
        if let basePointer = snapshot.candidates {
            for index in 0..<candidateCount {
                let candidate = basePointer[index]
                let rawText = candidate.text.map { String(cString: $0) } ?? ""
                let text = renderedSurface(rawText)
                let comment = candidate.comment.map { String(cString: $0) } ?? ""
                let consumption = lexicon.consumption(
                    forSurface: rawText,
                    rawInput: rawInput,
                    comment: comment,
                    tokenizer: tokenizer
                )
                consumptions.append(consumption)
                candidates.append(
                    Candidate(
                        id: "rime:\(snapshot.pageNo):\(index):\(text)",
                        surface: text,
                        reading: comment.isEmpty ? rawInput : comment,
                        score: max(0, candidateCount - index),
                        consumedTokenCount: consumption.tokenCount
                    )
                )
            }
        }

        if candidates.isEmpty {
            return rawBufferSnapshot(for: rawInput)
        }

        let selectedConsumption =
            selectedIndex < consumptions.count
            ? consumptions[selectedIndex]
            : RimeConsumption(tokenCount: 0, tokens: tokenizer.tokenize(rawInput) ?? [])
        let selectedConsumed = selectedConsumption.tokenCount
        let tokens = selectedConsumption.tokens
        let activeRawInput =
            selectedConsumed > 0 ? Array(tokens.prefix(selectedConsumed)).joined() : ""
        let remainingRawInput =
            selectedConsumed > 0 ? Array(tokens.dropFirst(selectedConsumed)).joined() : rawInput

        return CompositionSnapshot(
            rawInput: rawInput,
            markedText: preeditText,
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
        PinyinTokenizer.normalizeInput(input)
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

    private func processCharacters<S: Sequence>(_ characters: S) -> Bool
    where S.Element == Character {
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
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1
        else {
            return nil
        }
        guard scalar.isASCII else {
            return nil
        }
        return Int32(scalar.value)
    }

    private func renderedSurface(_ surface: String) -> String {
        switch settings.characterForm {
        case .simplified:
            return surface.applyingRimeLexiconSimplifiedFallbacks()
        case .traditional:
            return surface
        }
    }
}
