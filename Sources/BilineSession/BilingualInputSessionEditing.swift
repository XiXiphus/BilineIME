import BilineCore

extension BilingualInputSession {
    public func append(text: String) {
        withStateLock {
            let normalized = normalize(text)
            guard !normalized.isEmpty else { return }
            advanceCompositionRevision()
            rawInput.append(contentsOf: normalized)
            refreshCompositionState()
        }
    }

    public func appendLiteral(text: String) {
        withStateLock {
            guard !text.isEmpty else { return }
            advanceCompositionRevision()
            rawInput.append(contentsOf: text)
            refreshCompositionState()
        }
    }

    public func deleteBackward() {
        withStateLock {
            guard !rawInput.isEmpty else { return }
            advanceCompositionRevision()
            rawInput.removeLast()
            refreshCompositionState()
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

        guard hasValidQueryInput else {
            clearPreviews()
            compositionMode = .rawBufferOnly
            presentationMode = .compact
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

        presentationMode = .compact
        updateEngineSnapshot(engineSession.updateInput(rawInput))
    }

    func resetCompositionState() {
        rawInput = ""
        engineSnapshot = engineSession.reset()
        activeLayer = .chinese
        compositionMode = .candidateCompact
        hasEverExpandedInCurrentComposition = false
        presentationMode = .compact
        clearPreviews()
        publishSnapshot()
    }
}
