import BilineCore
import BilinePreview
import Foundation

public enum ActiveLayer: String, Sendable, Equatable, Codable {
    case chinese
    case english
}

public enum BilingualPreviewState: Sendable, Equatable {
    case unavailable
    case loading
    case ready(String)
    case failed
}

public struct BilingualCandidateItem: Sendable, Equatable, Identifiable {
    public let candidate: Candidate
    public let previewState: BilingualPreviewState

    public init(candidate: Candidate, previewState: BilingualPreviewState) {
        self.candidate = candidate
        self.previewState = previewState
    }

    public var id: String {
        candidate.id
    }

    public var englishText: String? {
        guard case let .ready(text) = previewState else {
            return nil
        }
        return text
    }

    public var canCommitEnglish: Bool {
        englishText != nil
    }
}

public struct BilingualCompositionSnapshot: Sendable, Equatable {
    public let rawInput: String
    public let markedText: String
    public let items: [BilingualCandidateItem]
    public let selectedIndex: Int
    public let pageIndex: Int
    public let activeLayer: ActiveLayer
    public let isComposing: Bool

    public init(
        rawInput: String,
        markedText: String,
        items: [BilingualCandidateItem],
        selectedIndex: Int,
        pageIndex: Int,
        activeLayer: ActiveLayer,
        isComposing: Bool
    ) {
        self.rawInput = rawInput
        self.markedText = markedText
        self.items = items
        self.selectedIndex = selectedIndex
        self.pageIndex = pageIndex
        self.activeLayer = activeLayer
        self.isComposing = isComposing
    }

    public static let idle = BilingualCompositionSnapshot(
        rawInput: "",
        markedText: "",
        items: [],
        selectedIndex: 0,
        pageIndex: 0,
        activeLayer: .chinese,
        isComposing: false
    )
}

public final class BilingualInputSession: @unchecked Sendable {
    public var onSnapshotUpdate: ((BilingualCompositionSnapshot) -> Void)?

    public private(set) var snapshot: BilingualCompositionSnapshot = .idle

    private let settingsStore: any SettingsStore
    private let previewCoordinator: PreviewCoordinator
    private var engineSession: any CandidateEngineSession

    private var engineSnapshot: CompositionSnapshot = .idle
    private var rawInput = ""
    private var activeLayer: ActiveLayer = .chinese
    private var previewStates: [String: BilingualPreviewState] = [:]
    private var previewTasks: [String: Task<Void, Never>] = [:]
    private let sessionID = UUID()

    public init(
        settingsStore: any SettingsStore,
        engineFactory: any CandidateEngineFactory,
        previewCoordinator: PreviewCoordinator
    ) {
        self.settingsStore = settingsStore
        self.previewCoordinator = previewCoordinator
        self.engineSession = engineFactory.makeSession(
            config: EngineConfig(pageSize: settingsStore.pageSize)
        )
    }

    deinit {
        clearPreviews()
    }

    public func append(text: String) {
        rawInput.append(contentsOf: normalize(text))
        updateEngineSnapshot(engineSession.updateInput(rawInput))
    }

    public func deleteBackward() {
        guard !rawInput.isEmpty else { return }
        rawInput.removeLast()
        updateEngineSnapshot(engineSession.updateInput(rawInput))
    }

    public func moveSelection(_ direction: SelectionDirection) {
        guard engineSnapshot.isComposing else { return }
        updateEngineSnapshot(engineSession.moveSelection(direction))
    }

    public func turnPage(_ direction: PageDirection) {
        guard engineSnapshot.isComposing else { return }
        updateEngineSnapshot(engineSession.turnPage(direction))
    }

    public func selectCandidate(at localIndex: Int) {
        guard localIndex >= 0, localIndex < engineSnapshot.candidates.count else { return }

        let delta = localIndex - engineSnapshot.selectedIndex
        guard delta != 0 else {
            publishSnapshot()
            return
        }

        let direction: SelectionDirection = delta > 0 ? .next : .previous
        for _ in 0..<abs(delta) {
            engineSnapshot = engineSession.moveSelection(direction)
        }
        updateEngineSnapshot(engineSnapshot)
    }

    public func toggleActiveLayer() {
        guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else { return }
        activeLayer = activeLayer == .chinese ? .english : .chinese
        publishSnapshot()
    }

    public func commitSelection() -> String? {
        guard engineSnapshot.isComposing else { return nil }

        let englishSelection = currentItem?.englishText
        if activeLayer == .english, englishSelection == nil {
            publishSnapshot()
            return nil
        }

        let commitResult = engineSession.commitSelected()
        let committedText: String
        switch activeLayer {
        case .chinese:
            committedText = commitResult.committedText
        case .english:
            committedText = englishSelection ?? ""
        }

        rawInput = ""
        engineSnapshot = commitResult.snapshot
        activeLayer = .chinese
        clearPreviews()
        publishSnapshot()
        return committedText.isEmpty ? nil : committedText
    }

    public func cancel() {
        rawInput = ""
        engineSnapshot = engineSession.reset()
        activeLayer = .chinese
        clearPreviews()
        publishSnapshot()
    }

    private var currentItem: BilingualCandidateItem? {
        guard engineSnapshot.selectedIndex >= 0, engineSnapshot.selectedIndex < snapshot.items.count else {
            return nil
        }
        return snapshot.items[engineSnapshot.selectedIndex]
    }

    private func updateEngineSnapshot(_ newSnapshot: CompositionSnapshot) {
        let previousCandidateIDs = visibleCandidateIDs(for: engineSnapshot)
        engineSnapshot = newSnapshot

        if !engineSnapshot.isComposing {
            activeLayer = .chinese
        }

        let currentCandidateIDs = visibleCandidateIDs(for: engineSnapshot)
        if previousCandidateIDs != currentCandidateIDs {
            reconcilePreviews(
                previousCandidateIDs: previousCandidateIDs,
                visibleCandidates: engineSnapshot.candidates
            )
        } else {
            publishSnapshot()
        }
    }

    private func reconcilePreviews(
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
            publishSnapshot()
            return
        }

        for candidate in visibleCandidates where previewStates[candidate.id] == nil {
            previewStates[candidate.id] = .loading
            startPreview(for: candidate)
        }

        publishSnapshot()
    }

    private func startPreview(for candidate: Candidate) {
        previewTasks[candidate.id]?.cancel()

        let requestID = candidate.id
        let targetLanguage = settingsStore.targetLanguage
        previewTasks[candidate.id] = Task { [weak self, previewCoordinator, sessionID] in
            guard let self else { return }

            let initialState = await previewCoordinator.startPreview(
                sessionID: sessionID,
                requestID: requestID,
                selectionRevision: engineSnapshot.pageIndex,
                candidate: candidate,
                targetLanguage: targetLanguage
            )

            await MainActor.run {
                self.applyPreviewState(initialState, for: candidate.id, candidate: candidate)
            }

            guard case .loading = initialState else { return }

            let resolvedState = await previewCoordinator.resolvePreview(
                sessionID: sessionID,
                requestID: requestID,
                selectionRevision: engineSnapshot.pageIndex,
                candidate: candidate,
                targetLanguage: targetLanguage
            )

            await MainActor.run {
                self.applyPreviewState(resolvedState, for: candidate.id, candidate: candidate)
            }
        }
    }

    private func applyPreviewState(
        _ state: PreviewState,
        for candidateID: String,
        candidate: Candidate
    ) {
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

        if candidate.id == currentSelectedCandidateID {
            publishSnapshot()
        } else {
            snapshot = makeSnapshot()
            onSnapshotUpdate?(snapshot)
        }
    }

    private var currentSelectedCandidateID: String? {
        guard engineSnapshot.selectedIndex >= 0, engineSnapshot.selectedIndex < engineSnapshot.candidates.count else {
            return nil
        }
        return engineSnapshot.candidates[engineSnapshot.selectedIndex].id
    }

    private func makeSnapshot() -> BilingualCompositionSnapshot {
        guard engineSnapshot.isComposing else {
            return .idle
        }

        let items = engineSnapshot.candidates.map { candidate in
            BilingualCandidateItem(
                candidate: candidate,
                previewState: previewStates[candidate.id] ?? fallbackPreviewState()
            )
        }

        let markedText = makeMarkedText(items: items)
        return BilingualCompositionSnapshot(
            rawInput: engineSnapshot.rawInput,
            markedText: markedText,
            items: items,
            selectedIndex: engineSnapshot.selectedIndex,
            pageIndex: engineSnapshot.pageIndex,
            activeLayer: activeLayer,
            isComposing: engineSnapshot.isComposing
        )
    }

    private func makeMarkedText(items: [BilingualCandidateItem]) -> String {
        guard engineSnapshot.selectedIndex >= 0, engineSnapshot.selectedIndex < items.count else {
            return engineSnapshot.markedText
        }

        let selectedItem = items[engineSnapshot.selectedIndex]
        if activeLayer == .english, let englishText = selectedItem.englishText {
            return englishText
        }
        return selectedItem.candidate.surface
    }

    private func publishSnapshot() {
        snapshot = makeSnapshot()
        onSnapshotUpdate?(snapshot)
    }

    private func clearPreviews() {
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

    private func visibleCandidateIDs(for snapshot: CompositionSnapshot) -> Set<String> {
        Set(snapshot.candidates.map(\.id))
    }

    private func fallbackPreviewState() -> BilingualPreviewState {
        settingsStore.previewEnabled ? .loading : .unavailable
    }

    private func normalize(_ string: String) -> String {
        string
            .lowercased()
            .filter { $0.isLetter || $0 == "'" }
    }
}
