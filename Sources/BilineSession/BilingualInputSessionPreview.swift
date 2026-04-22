import BilineCore
import BilinePreview
import Foundation

extension BilingualInputSession {
    func reconcilePreviews(
        previousCandidateIDs: Set<String>,
        visibleCandidates: [Candidate]
    ) {
        let visibleCandidateIDs = Set(visibleCandidates.map(\.id))
        let removedIDs = previousCandidateIDs.subtracting(visibleCandidateIDs)

        for removedID in removedIDs {
            previewTasks[removedID]?.cancel()
            previewTasks.removeValue(forKey: removedID)
            previewStates.removeValue(forKey: removedID)
            Task { [previewCoordinator, sessionID] in
                await previewCoordinator.cancel(sessionID: sessionID, requestID: removedID)
            }
        }

        guard settingsStore.previewEnabled else {
            for candidate in visibleCandidates {
                previewStates[candidate.id] = .unavailable
            }
            cancelUnselectedPreviewTasks(selectedID: nil)
            publishSnapshot()
            return
        }

        publishSnapshot()
    }

    func prepareSelectedPreview() {
        guard settingsStore.previewEnabled, engineSnapshot.isComposing else {
            cancelUnselectedPreviewTasks(selectedID: nil)
            return
        }
        guard let selectedID = currentSelectedCandidateID,
            let selectedCandidate = engineSnapshot.candidates.first(where: { $0.id == selectedID })
        else {
            cancelUnselectedPreviewTasks(selectedID: nil)
            return
        }

        cancelUnselectedPreviewTasks(selectedID: selectedID)

        if previewStates[selectedID] == nil {
            previewStates[selectedID] = .loading
            startPreview(for: selectedCandidate, revision: compositionRevision)
        }
    }

    func startPreview(for candidate: Candidate, revision: Int) {
        previewTasks[candidate.id]?.cancel()

        let requestID = candidate.id
        let targetLanguage = settingsStore.targetLanguage
        let selectionRevision = revision
        let priority: PreviewRequestPriority =
            candidate.id == currentSelectedCandidateID ? .selected : .visible
        previewTasks[candidate.id] = Task { [weak self, previewCoordinator, sessionID] in
            guard let self else { return }

            let initialState = await previewCoordinator.startPreview(
                sessionID: sessionID,
                requestID: requestID,
                selectionRevision: selectionRevision,
                candidate: candidate,
                targetLanguage: targetLanguage,
                priority: priority
            )

            await MainActor.run {
                self.applyPreviewState(
                    initialState,
                    for: candidate.id,
                    candidate: candidate,
                    revision: revision
                )
            }

            guard case .loading = initialState else { return }

            let resolvedState = await previewCoordinator.resolvePreview(
                sessionID: sessionID,
                requestID: requestID,
                selectionRevision: selectionRevision,
                candidate: candidate,
                targetLanguage: targetLanguage,
                priority: priority
            )

            await MainActor.run {
                self.applyPreviewState(
                    resolvedState,
                    for: candidate.id,
                    candidate: candidate,
                    revision: revision
                )
            }
        }
    }

    func applyPreviewState(
        _ state: PreviewState,
        for candidateID: String,
        candidate: Candidate,
        revision: Int
    ) {
        withStateLock {
            guard revision == compositionRevision else {
                return
            }
            guard engineSnapshot.isComposing, candidateID == currentSelectedCandidateID else {
                return
            }
            guard visibleCandidateIDs(for: engineSnapshot).contains(candidateID) else {
                return
            }

            switch state {
            case .idle:
                previewStates[candidateID] = .loading
            case .loading:
                previewStates[candidateID] = .loading
            case .failed:
                previewStates[candidateID] = .failed
            case .ready(_, let preview):
                previewStates[candidateID] = .ready(preview)
            }

            if case .ready = state {
                previewTasks.removeValue(forKey: candidateID)
            }

            if case .failed = state {
                previewTasks.removeValue(forKey: candidateID)
            }

            publishSnapshot()
        }
    }

    func cancelUnselectedPreviewTasks(selectedID: String?) {
        let unselectedIDs = previewTasks.keys.filter { $0 != selectedID }
        for candidateID in unselectedIDs {
            previewTasks[candidateID]?.cancel()
            previewTasks.removeValue(forKey: candidateID)
            if case .loading = previewStates[candidateID] {
                previewStates.removeValue(forKey: candidateID)
            }
            Task { [previewCoordinator, sessionID] in
                await previewCoordinator.cancel(sessionID: sessionID, requestID: candidateID)
            }
        }
    }

    var currentSelectedCandidateID: String? {
        guard currentSelectedFlatIndex >= 0,
            currentSelectedFlatIndex < engineSnapshot.candidates.count
        else {
            return nil
        }
        return engineSnapshot.candidates[currentSelectedFlatIndex].id
    }

    func clearPreviews() {
        for task in previewTasks.values {
            task.cancel()
        }
        previewTasks.removeAll()
        previewStates.removeAll()
        let sessionID = self.sessionID
        Task { [previewCoordinator] in
            await previewCoordinator.cancel(sessionID: sessionID)
        }
    }

    func visibleCandidateIDs(for snapshot: CompositionSnapshot) -> Set<String> {
        Set(snapshot.candidates.map(\.id))
    }

    func fallbackPreviewState() -> BilingualPreviewState {
        .unavailable
    }

    public func applyBilingualModeSetting() {
        withStateLock {
            if !showsEnglishCandidates {
                activeLayer = .chinese
                clearPreviews()
            }
            guard engineSnapshot.isComposing else { return }
            publishSnapshot()
        }
    }
}
