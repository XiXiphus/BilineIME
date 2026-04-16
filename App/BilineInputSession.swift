import BilineCore
import BilineMocks
import BilinePreview
import Foundation

final class BilineInputSession: @unchecked Sendable {
    var onPreviewUpdate: ((String?) -> Void)?

    private let settingsStore: DefaultSettingsStore
    private let previewCoordinator: PreviewCoordinator
    private var engineSession: any CandidateEngineSession

    private(set) var snapshot: CompositionSnapshot = .idle
    private(set) var previewText: String?

    private var rawInput = ""
    private var selectionRevision = 0
    private var previewTask: Task<Void, Never>?
    private let sessionID = UUID()

    init(
        settingsStore: DefaultSettingsStore,
        engineFactory: FixtureCandidateEngineFactory,
        previewCoordinator: PreviewCoordinator
    ) {
        self.settingsStore = settingsStore
        self.previewCoordinator = previewCoordinator
        self.engineSession = engineFactory.makeSession(
            config: EngineConfig(pageSize: settingsStore.pageSize)
        )
    }

    var candidateStrings: [String] {
        snapshot.candidates.map(\.surface)
    }

    func append(text: String) {
        rawInput.append(contentsOf: normalize(text))
        snapshot = engineSession.updateInput(rawInput)
        selectionRevision += 1
        schedulePreview()
    }

    func deleteBackward() {
        guard !rawInput.isEmpty else { return }
        rawInput.removeLast()
        snapshot = engineSession.updateInput(rawInput)
        selectionRevision += 1
        schedulePreview()
    }

    func moveSelection(_ direction: SelectionDirection) {
        guard snapshot.isComposing else { return }
        snapshot = engineSession.moveSelection(direction)
        selectionRevision += 1
        schedulePreview()
    }

    func turnPage(_ direction: PageDirection) {
        guard snapshot.isComposing else { return }
        snapshot = engineSession.turnPage(direction)
        selectionRevision += 1
        schedulePreview()
    }

    func selectCandidate(at localIndex: Int) {
        guard localIndex >= 0, localIndex < snapshot.candidates.count else { return }

        let delta = localIndex - snapshot.selectedIndex
        guard delta != 0 else {
            schedulePreview()
            return
        }

        let direction: SelectionDirection = delta > 0 ? .next : .previous
        for _ in 0..<abs(delta) {
            snapshot = engineSession.moveSelection(direction)
        }
        selectionRevision += 1
        schedulePreview()
    }

    func updateSelection(for surface: String) {
        guard let index = snapshot.candidates.firstIndex(where: { $0.surface == surface }) else {
            return
        }
        selectCandidate(at: index)
    }

    func commitSelection() -> String? {
        guard snapshot.isComposing else { return nil }
        let result = engineSession.commitSelected()
        rawInput = ""
        snapshot = result.snapshot
        clearPreview()
        return result.committedText.isEmpty ? nil : result.committedText
    }

    func cancel() {
        rawInput = ""
        snapshot = engineSession.reset()
        clearPreview()
    }

    private func schedulePreview() {
        previewTask?.cancel()
        let sessionID = self.sessionID

        guard settingsStore.annotationEnabled, let candidate = selectedCandidate else {
            previewText = nil
            onPreviewUpdate?(nil)
            Task { [previewCoordinator, sessionID] in
                await previewCoordinator.cancel(sessionID: sessionID)
            }
            return
        }

        let revision = selectionRevision
        let targetLanguage = settingsStore.targetLanguage

        previewTask = Task { [weak self, previewCoordinator, sessionID] in
            guard let self else { return }

            let initialState = await previewCoordinator.startPreview(
                sessionID: sessionID,
                selectionRevision: revision,
                candidate: candidate,
                targetLanguage: targetLanguage
            )

            await MainActor.run {
                self.applyPreviewState(initialState, expectedRevision: revision)
            }

            guard case .loading = initialState else { return }

            let resolvedState = await previewCoordinator.resolvePreview(
                sessionID: sessionID,
                selectionRevision: revision,
                candidate: candidate,
                targetLanguage: targetLanguage
            )

            await MainActor.run {
                self.applyPreviewState(resolvedState, expectedRevision: revision)
            }
        }
    }

    private var selectedCandidate: Candidate? {
        guard snapshot.selectedIndex < snapshot.candidates.count else {
            return nil
        }
        return snapshot.candidates[snapshot.selectedIndex]
    }

    private func applyPreviewState(_ state: PreviewState, expectedRevision: Int) {
        guard expectedRevision == selectionRevision else { return }

        switch state {
        case .idle, .loading, .failed:
            previewText = nil
        case .ready(_, let preview):
            previewText = preview
        }

        onPreviewUpdate?(previewText)
    }

    private func clearPreview() {
        previewTask?.cancel()
        previewTask = nil
        previewText = nil
        onPreviewUpdate?(nil)
        let sessionID = self.sessionID
        Task { [previewCoordinator, sessionID] in
            await previewCoordinator.cancel(sessionID: sessionID)
        }
    }

    private func normalize(_ string: String) -> String {
        string
            .lowercased()
            .filter { $0.isLetter || $0 == "'" }
    }
}
