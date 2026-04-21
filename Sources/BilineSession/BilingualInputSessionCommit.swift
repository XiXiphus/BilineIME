import BilineCore

extension BilingualInputSession {
    public func commitSelection() -> String? {
        withStateLock {
            commitSelection(for: activeLayer)
        }
    }

    public func commitChineseSelection() -> String? {
        withStateLock {
            commitSelection(for: .chinese)
        }
    }

    public func commitRawInput() -> String? {
        withStateLock {
            guard engineSnapshot.isComposing else { return nil }
            let committedText = engineSnapshot.candidates.isEmpty ? renderedRawInput : rawInput
            guard !committedText.isEmpty else {
                publishSnapshot()
                return nil
            }
            advanceCompositionRevision()
            resetCompositionState()
            return committedText
        }
    }

    public func renderCommittedText(_ text: String) -> String {
        PunctuationPolicy.renderCommittedText(text, form: settingsStore.punctuationForm)
    }

    private func commitSelection(for layer: ActiveLayer) -> String? {
        guard engineSnapshot.isComposing else { return nil }

        if engineSnapshot.candidates.isEmpty {
            let committedText = renderedRawInput
            resetCompositionState()
            return committedText.isEmpty ? nil : committedText
        }

        guard let item = currentItem else {
            publishSnapshot()
            return nil
        }

        let englishSelection = item.englishText
        if layer == .english, englishSelection == nil {
            publishSnapshot()
            return nil
        }

        let commitsWholeComposition =
            item.candidate.consumedTokenCount > 0 && engineSnapshot.remainingRawInput.isEmpty
        let fallbackTailInput =
            engineSnapshot.consumedTokenCount > 0 ? engineSnapshot.remainingRawInput : ""

        let engineCommit = engineSession.commitSelected()

        let committedText = finalizedCurrentSelectionText(
            for: layer,
            englishSelection: englishSelection,
            engineCommittedText: engineCommit.committedText
        )
        guard !committedText.isEmpty else {
            publishSnapshot()
            return nil
        }

        advanceCompositionRevision()

        if commitsWholeComposition {
            resetCompositionState()
            return committedText
        }

        if engineSnapshot.consumedTokenCount == 0,
            engineCommit.snapshot.isComposing,
            engineCommit.snapshot.rawInput == rawInput
        {
            resetCompositionState()
            return committedText
        }

        if engineCommit.snapshot.isComposing {
            rawInput = engineCommit.snapshot.rawInput
            activeLayer = layer
            hasEverExpandedInCurrentComposition = false
            hasExplicitCandidateSelection = false
            presentationMode = .compact
            clearPreviews()
            updateEngineSnapshot(engineCommit.snapshot)
            return committedText
        }

        if !fallbackTailInput.isEmpty {
            rawInput = fallbackTailInput
            activeLayer = layer
            hasEverExpandedInCurrentComposition = false
            hasExplicitCandidateSelection = false
            presentationMode = .compact
            clearPreviews()
            updateEngineSnapshot(engineSession.updateInput(rawInput))
            return committedText
        }

        resetCompositionState()
        return committedText
    }

    private func finalizedCurrentSelectionText(
        for layer: ActiveLayer,
        englishSelection: String?,
        engineCommittedText: String
    ) -> String {
        guard let item = currentItem else { return "" }
        switch layer {
        case .chinese:
            return engineCommittedText.isEmpty ? item.candidate.surface : engineCommittedText
        case .english:
            return englishSelection ?? ""
        }
    }
}
