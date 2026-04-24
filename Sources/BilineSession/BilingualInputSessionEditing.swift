import BilineCore

extension BilingualInputSession {
    public func append(text: String) {
        withStateLock {
            let normalized = normalize(text)
            guard !normalized.isEmpty else { return }
            advanceCompositionRevision()
            insertRawText(normalized)
            resetCandidateBrowsingStateForRawEdit()
            refreshCompositionState()
        }
    }

    public func appendLiteral(text: String) {
        withStateLock {
            guard !text.isEmpty else { return }
            advanceCompositionRevision()
            insertRawText(text)
            resetCandidateBrowsingStateForRawEdit()
            refreshCompositionState()
        }
    }

    public func deleteBackward() {
        withStateLock {
            guard !rawInput.isEmpty else { return }
            clampRawCursorIndex()
            if rawCursorIndex == 0 {
                rawCursorIndex = rawInput.count
            }
            advanceCompositionRevision()
            let endIndex = rawInput.index(rawInput.startIndex, offsetBy: rawCursorIndex)
            let startIndex = rawInput.index(before: endIndex)
            rawInput.removeSubrange(startIndex..<endIndex)
            rawCursorIndex -= 1
            resetCandidateBrowsingStateForRawEdit()
            refreshCompositionState()
        }
    }

    public func deleteRawBackwardByBlock() {
        withStateLock {
            guard !rawInput.isEmpty else { return }
            clampRawCursorIndex()
            if rawCursorIndex == 0 {
                rawCursorIndex = rawInput.count
            }

            let startOffset = pinyinSegmenter.previousBlockBoundary(
                in: rawInput,
                from: rawCursorIndex
            )
            guard startOffset < rawCursorIndex else {
                publishSnapshot()
                return
            }

            advanceCompositionRevision()
            let startIndex = rawInput.index(rawInput.startIndex, offsetBy: startOffset)
            let endIndex = rawInput.index(rawInput.startIndex, offsetBy: rawCursorIndex)
            rawInput.removeSubrange(startIndex..<endIndex)
            rawCursorIndex = startOffset
            resetCandidateBrowsingStateForRawEdit()
            refreshCompositionState()
        }
    }

    public func deleteRawToStart() {
        withStateLock {
            guard !rawInput.isEmpty else { return }
            clampRawCursorIndex()
            guard rawCursorIndex > 0 else {
                publishSnapshot()
                return
            }

            advanceCompositionRevision()
            let endIndex = rawInput.index(rawInput.startIndex, offsetBy: rawCursorIndex)
            rawInput.removeSubrange(rawInput.startIndex..<endIndex)
            rawCursorIndex = 0
            resetCandidateBrowsingStateForRawEdit()
            refreshCompositionState()
        }
    }

    public func moveRawCursorByBlock(_ direction: SelectionDirection) {
        withStateLock {
            guard !rawInput.isEmpty else { return }
            let nextIndex: Int
            switch direction {
            case .previous:
                nextIndex = pinyinSegmenter.previousBlockBoundary(
                    in: rawInput, from: rawCursorIndex)
            case .next:
                nextIndex = pinyinSegmenter.nextBlockBoundary(in: rawInput, from: rawCursorIndex)
            }
            guard nextIndex != rawCursorIndex else {
                publishSnapshot()
                return
            }
            rawCursorIndex = nextIndex
            publishSnapshot()
        }
    }

    public func moveRawCursorByCharacter(_ direction: SelectionDirection) {
        withStateLock {
            guard !rawInput.isEmpty else { return }
            clampRawCursorIndex()
            let nextIndex: Int
            switch direction {
            case .previous:
                nextIndex = max(0, rawCursorIndex - 1)
            case .next:
                nextIndex = min(rawInput.count, rawCursorIndex + 1)
            }
            guard nextIndex != rawCursorIndex else {
                publishSnapshot()
                return
            }
            rawCursorIndex = nextIndex
            publishSnapshot()
        }
    }

    public func moveRawCursorToStart() {
        withStateLock {
            guard !rawInput.isEmpty else { return }
            guard rawCursorIndex != 0 else {
                publishSnapshot()
                return
            }
            rawCursorIndex = 0
            publishSnapshot()
        }
    }

    public func moveRawCursorToEnd() {
        withStateLock {
            guard !rawInput.isEmpty else { return }
            let endIndex = rawInput.count
            guard rawCursorIndex != endIndex else {
                publishSnapshot()
                return
            }
            rawCursorIndex = endIndex
            publishSnapshot()
        }
    }

    public func cancel() {
        withStateLock {
            advanceCompositionRevision()
            resetCompositionState()
        }
    }

    func refreshCompositionState() {
        guard !rawInput.isEmpty else {
            resetCompositionState()
            return
        }
        clampRawCursorIndex()

        if !hasValidQueryInput, let mixed = mixedUppercaseLatinComposition() {
            rawSuffixAfterActiveChunk = mixed.rawSuffix
            displaySuffixForWholeCandidate = mixed.displaySuffix
            presentationMode = .compact
            preferredCandidateColumn = 0
            updateEngineSnapshot(engineSession.updateInput(mixed.queryInput))
            return
        }

        guard hasValidQueryInput else {
            rawSuffixAfterActiveChunk = ""
            displaySuffixForWholeCandidate = ""
            clearPreviews()
            compositionMode = .rawBufferOnly
            presentationMode = .compact
            preferredCandidateColumn = 0
            engineSnapshot = CompositionSnapshot(
                rawInput: rawInput,
                markedText: renderedRawInput,
                candidates: [],
                selectedIndex: 0,
                pageIndex: 0,
                isComposing: true,
                activeRawInput: "",
                remainingRawInput: rawInput,
                consumedTokenCount: 0
            )
            publishSnapshot()
            return
        }

        rawSuffixAfterActiveChunk = ""
        displaySuffixForWholeCandidate = ""
        presentationMode = .compact
        preferredCandidateColumn = 0
        updateEngineSnapshot(engineSession.updateInput(rawInput))
    }

    func resetCompositionState() {
        rawInput = ""
        rawCursorIndex = 0
        rawSuffixAfterActiveChunk = ""
        displaySuffixForWholeCandidate = ""
        engineSnapshot = engineSession.reset()
        activeLayer = .chinese
        compositionMode = .candidateCompact
        hasEverExpandedInCurrentComposition = false
        hasExplicitCandidateSelection = false
        presentationMode = .compact
        preferredCandidateColumn = 0
        clearPreviews()
        publishSnapshot()
    }

    func insertRawText(_ text: String) {
        clampRawCursorIndex()
        let index = rawInput.index(rawInput.startIndex, offsetBy: rawCursorIndex)
        rawInput.insert(contentsOf: text, at: index)
        rawCursorIndex += text.count
    }

    func clampRawCursorIndex() {
        rawCursorIndex = min(max(0, rawCursorIndex), rawInput.count)
    }

    func resetCandidateBrowsingStateForRawEdit() {
        hasExplicitCandidateSelection = false
        hasEverExpandedInCurrentComposition = false
        presentationMode = .compact
        preferredCandidateColumn = 0
    }

    func mixedUppercaseLatinComposition() -> (
        queryInput: String,
        rawSuffix: String,
        displaySuffix: String
    )? {
        guard !rawInput.isEmpty else { return nil }

        guard
            let suffixStart = rawInput.firstIndex(where: { character in
                character.unicodeScalars.count == 1
                    && character.unicodeScalars.first.map { (65...90).contains($0.value) } == true
            })
        else {
            return nil
        }

        let rawSuffix = String(rawInput[suffixStart...])
        let queryInput = String(rawInput[..<suffixStart])
        guard !rawSuffix.isEmpty,
            !queryInput.isEmpty,
            queryInput == normalize(queryInput)
        else {
            return nil
        }

        return (
            queryInput,
            rawSuffix,
            renderDisplaySuffix(from: rawSuffix)
        )
    }

    func renderDisplaySuffix(from rawSuffix: String) -> String {
        guard !rawSuffix.isEmpty else { return "" }

        var rendered = ""
        var chunk = ""
        let characters = Array(rawSuffix)

        func flushPinyinChunk() {
            guard !chunk.isEmpty else { return }
            let snapshot = engineSession.updateInput(chunk)
            rendered += snapshot.candidates.first?.surface ?? chunk
            chunk.removeAll(keepingCapacity: true)
        }

        for character in characters {
            guard character.unicodeScalars.count == 1,
                let scalar = character.unicodeScalars.first
            else {
                flushPinyinChunk()
                rendered.append(character)
                continue
            }

            switch scalar.value {
            case 65...90:
                flushPinyinChunk()
                rendered.unicodeScalars.append(scalar)
            case 97...122, 39:
                chunk.append(character)
            default:
                flushPinyinChunk()
                rendered.append(character)
            }
        }

        flushPinyinChunk()
        return rendered
    }
}
