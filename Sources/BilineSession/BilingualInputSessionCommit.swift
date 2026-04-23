import BilineCore
import Foundation

extension BilingualInputSession {
    public func commitSelection() -> String? {
        withStateLock {
            commitSelection(for: effectiveActiveLayer).map { applyPostCommitPipeline(to: $0) }
        }
    }

    public func commitChineseSelection() -> String? {
        withStateLock {
            commitSelection(for: .chinese).map { applyPostCommitPipeline(to: $0) }
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
            return applyPostCommitPipeline(to: committedText)
        }
    }

    public func renderCommittedText(_ text: String) -> String {
        let rendered = PunctuationPolicy.renderCommittedText(text, form: settingsStore.punctuationForm)
        return applyPostCommitPipeline(to: rendered)
    }

    /// Runs the configured `PostCommitPipeline` against `text` and updates
    /// the session's "last commit" memory so the next call sees this commit
    /// in its `PostCommitContext`. Empty pipeline short-circuits to keep the
    /// hot path free of allocations when no transforms are configured.
    func applyPostCommitPipeline(to text: String) -> String {
        let context = PostCommitContext(
            lastCommittedText: lastCommitTextForPipeline,
            lastCommitTimestamp: lastCommitTimestampForPipeline,
            hostBundleID: hostBundleID,
            punctuationForm: settingsStore.punctuationForm,
            commitHistory: commitHistoryForPipeline
        )
        let result = postCommitPipeline.isEmpty
            ? text
            : postCommitPipeline.apply(text, context: context)
        if !result.isEmpty {
            lastCommitTextForPipeline = result
            lastCommitTimestampForPipeline = Date()
            commitHistoryForPipeline.append(result)
            let limit = PostCommitContext.commitHistoryLimit
            if commitHistoryForPipeline.count > limit {
                commitHistoryForPipeline.removeFirst(commitHistoryForPipeline.count - limit)
            }
        }
        return result
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

        if !literalLatinSuffix.isEmpty, !fallbackTailInput.isEmpty {
            rawInput = fallbackTailInput
            rawCursorIndex = rawInput.count
            activeLayer = layer
            hasEverExpandedInCurrentComposition = false
            hasExplicitCandidateSelection = false
            presentationMode = .compact
            clearPreviews()
            refreshCompositionState()
            return committedText
        }

        if engineCommit.snapshot.isComposing {
            rawInput = engineCommit.snapshot.rawInput
            rawCursorIndex = rawInput.count
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
            rawCursorIndex = rawInput.count
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
            let committedText =
                engineCommittedText.isEmpty ? item.candidate.surface : engineCommittedText
            guard !literalLatinSuffix.isEmpty,
                item.candidate.surface.hasSuffix(literalLatinSuffix),
                !committedText.hasSuffix(literalLatinSuffix)
            else {
                return committedText
            }
            return committedText + literalLatinSuffix
        case .english:
            return englishSelection ?? ""
        }
    }
}
