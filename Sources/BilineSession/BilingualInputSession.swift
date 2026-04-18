import BilineCore
import BilinePreview
import Foundation

public enum ActiveLayer: String, Sendable, Equatable, Codable {
    case chinese
    case english
}

public enum CandidatePresentationMode: String, Sendable, Equatable, Codable {
    case compact
    case expanded
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
    public let pageIndex: Int
    public let activeLayer: ActiveLayer
    public let presentationMode: CandidatePresentationMode
    public let selectedRow: Int
    public let selectedColumn: Int
    public let compactColumnCount: Int
    public let expandedRowCount: Int
    public let isComposing: Bool

    public init(
        rawInput: String,
        markedText: String,
        items: [BilingualCandidateItem],
        pageIndex: Int,
        activeLayer: ActiveLayer,
        presentationMode: CandidatePresentationMode,
        selectedRow: Int,
        selectedColumn: Int,
        compactColumnCount: Int,
        expandedRowCount: Int,
        isComposing: Bool
    ) {
        self.rawInput = rawInput
        self.markedText = markedText
        self.items = items
        self.pageIndex = pageIndex
        self.activeLayer = activeLayer
        self.presentationMode = presentationMode
        self.selectedRow = selectedRow
        self.selectedColumn = selectedColumn
        self.compactColumnCount = max(1, compactColumnCount)
        self.expandedRowCount = max(1, expandedRowCount)
        self.isComposing = isComposing
    }

    public static let idle = BilingualCompositionSnapshot(
        rawInput: "",
        markedText: "",
        items: [],
        pageIndex: 0,
        activeLayer: .chinese,
        presentationMode: .compact,
        selectedRow: 0,
        selectedColumn: 0,
        compactColumnCount: 5,
        expandedRowCount: 5,
        isComposing: false
    )

    public var selectedFlatIndex: Int {
        selectedRow * compactColumnCount + selectedColumn
    }

    public var totalRowCount: Int {
        guard !items.isEmpty else { return 0 }
        return ((items.count - 1) / compactColumnCount) + 1
    }

    public var visibleRowCount: Int {
        switch presentationMode {
        case .compact:
            return min(totalRowCount, 1)
        case .expanded:
            return min(totalRowCount, expandedRowCount)
        }
    }

    public func item(row: Int, column: Int) -> BilingualCandidateItem? {
        guard row >= 0, column >= 0 else { return nil }
        let index = row * compactColumnCount + column
        guard index < items.count else { return nil }
        return items[index]
    }

    public func items(inRow row: Int) -> [BilingualCandidateItem] {
        guard row >= 0 else { return [] }
        let startIndex = row * compactColumnCount
        guard startIndex < items.count else { return [] }
        let endIndex = min(startIndex + compactColumnCount, items.count)
        return Array(items[startIndex..<endIndex])
    }
}

public final class BilingualInputSession: @unchecked Sendable {
    public var onSnapshotUpdate: ((BilingualCompositionSnapshot) -> Void)?

    public private(set) var snapshot: BilingualCompositionSnapshot = .idle
    public var canDeleteBackward: Bool { !rawInput.isEmpty }
    public var hasCandidates: Bool { !snapshot.items.isEmpty }

    private let settingsStore: any SettingsStore
    private let previewCoordinator: PreviewCoordinator
    private var engineSession: any CandidateEngineSession

    private var engineSnapshot: CompositionSnapshot = .idle
    private var rawInput = ""
    private var activeLayer: ActiveLayer = .chinese
    private var presentationMode: CandidatePresentationMode = .compact
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
        refreshCompositionState()
    }

    public func appendLiteral(text: String) {
        guard !text.isEmpty else { return }
        rawInput.append(contentsOf: text)
        refreshCompositionState()
    }

    public func deleteBackward() {
        guard !rawInput.isEmpty else { return }
        rawInput.removeLast()
        refreshCompositionState()
    }

    public func moveSelection(_ direction: SelectionDirection) {
        moveColumn(direction)
    }

    public func moveColumn(_ direction: SelectionDirection) {
        guard engineSnapshot.isComposing else { return }

        let delta = direction == .next ? 1 : -1
        let targetColumn = currentSelectedColumn + delta
        selectCandidate(
            row: currentSelectedRowForSelection,
            column: targetColumn,
            clampColumn: false
        )
    }

    public func moveRow(_ direction: SelectionDirection) {
        switch direction {
        case .next:
            browseNextRow()
        case .previous:
            browsePreviousRow()
        }
    }

    public func turnPage(_ direction: PageDirection) {
        guard engineSnapshot.isComposing else { return }
        guard !engineSnapshot.candidates.isEmpty else {
            publishSnapshot()
            return
        }

        moveToAdjacentPage(
            direction: direction,
            preferredColumn: currentSelectedColumn,
            preferredRow: currentSelectedRow
        )
    }

    public func selectCandidate(at localIndex: Int) {
        guard localIndex >= 0, localIndex < engineSnapshot.candidates.count else { return }
        moveEngineSelection(to: localIndex)
    }

    public func selectColumn(at columnIndex: Int) {
        guard engineSnapshot.isComposing else { return }
        selectCandidate(
            row: currentSelectedRowForSelection,
            column: columnIndex,
            clampColumn: false
        )
    }

    public func expandAndAdvanceRow() {
        guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else { return }

        let currentColumn = currentSelectedColumn
        presentationMode = .expanded

        let nextRow = 1
        if nextRow < currentRowCount {
            let targetColumn = min(currentColumn, max(0, candidateCount(inRow: nextRow) - 1))
            selectCandidate(row: nextRow, column: targetColumn, clampColumn: true)
            return
        }

        moveToAdjacentPage(
            direction: .next,
            preferredColumn: currentColumn,
            preferredRow: 0
        )
    }

    public func browseNextRow() {
        guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else {
            publishSnapshot()
            return
        }

        presentationMode = .expanded
        let targetRow = currentSelectedRow + 1
        if targetRow < currentRowCount {
            let targetColumn = min(currentSelectedColumn, max(0, candidateCount(inRow: targetRow) - 1))
            selectCandidate(row: targetRow, column: targetColumn, clampColumn: true)
            return
        }

        moveToAdjacentPage(direction: .next, preferredColumn: currentSelectedColumn, preferredRow: 0)
    }

    public func browsePreviousRow() {
        guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else {
            publishSnapshot()
            return
        }

        guard presentationMode == .expanded else {
            publishSnapshot()
            return
        }

        if currentSelectedRow == 0 {
            collapseToCompactAndSelectFirst()
            return
        }

        let targetRow = currentSelectedRow - 1
        let targetColumn = min(currentSelectedColumn, max(0, candidateCount(inRow: targetRow) - 1))
        selectCandidate(row: targetRow, column: targetColumn, clampColumn: true)
    }

    public func collapseToCompactAndSelectFirst() {
        guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else {
            publishSnapshot()
            return
        }

        presentationMode = .compact
        selectCandidate(row: 0, column: 0, clampColumn: true)
    }

    public func toggleActiveLayer() {
        guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else { return }
        activeLayer = activeLayer == .chinese ? .english : .chinese
        publishSnapshot()
    }

    public func commitSelection() -> String? {
        commitSelection(for: activeLayer)
    }

    public func commitChineseSelection() -> String? {
        commitSelection(for: .chinese)
    }

    private func commitSelection(for layer: ActiveLayer) -> String? {
        guard engineSnapshot.isComposing else { return nil }

        if engineSnapshot.candidates.isEmpty {
            let committedText = rawInput
            rawInput = ""
            engineSnapshot = engineSession.reset()
            activeLayer = .chinese
            presentationMode = .compact
            clearPreviews()
            publishSnapshot()
            return committedText.isEmpty ? nil : committedText
        }

        let englishSelection = currentItem?.englishText
        if layer == .english, englishSelection == nil {
            publishSnapshot()
            return nil
        }

        let commitResult = engineSession.commitSelected()
        let committedText: String
        switch layer {
        case .chinese:
            committedText = commitResult.committedText
        case .english:
            committedText = englishSelection ?? ""
        }

        rawInput = ""
        engineSnapshot = commitResult.snapshot
        activeLayer = .chinese
        presentationMode = .compact
        clearPreviews()
        publishSnapshot()
        return committedText.isEmpty ? nil : committedText
    }

    public func cancel() {
        rawInput = ""
        engineSnapshot = engineSession.reset()
        activeLayer = .chinese
        presentationMode = .compact
        clearPreviews()
        publishSnapshot()
    }

    private var compactColumnCount: Int {
        max(1, settingsStore.compactColumnCount)
    }

    private var expandedRowCount: Int {
        max(1, settingsStore.expandedRowCount)
    }

    private var currentSelectedFlatIndex: Int {
        engineSnapshot.selectedIndex
    }

    private var currentSelectedRow: Int {
        currentSelectedFlatIndex / compactColumnCount
    }

    private var currentSelectedColumn: Int {
        currentSelectedFlatIndex % compactColumnCount
    }

    private var currentSelectedRowForSelection: Int {
        presentationMode == .expanded ? currentSelectedRow : 0
    }

    private var currentRowCount: Int {
        rowCount(for: engineSnapshot.candidates)
    }

    private var currentItem: BilingualCandidateItem? {
        guard currentSelectedFlatIndex >= 0, currentSelectedFlatIndex < snapshot.items.count else {
            return nil
        }
        return snapshot.items[currentSelectedFlatIndex]
    }

    private var hasValidQueryInput: Bool {
        !rawInput.isEmpty && rawInput.allSatisfy { $0.isLetter || $0 == "'" }
    }

    private func refreshCompositionState() {
        guard !rawInput.isEmpty else {
            engineSnapshot = engineSession.reset()
            activeLayer = .chinese
            presentationMode = .compact
            clearPreviews()
            publishSnapshot()
            return
        }

        guard hasValidQueryInput else {
            clearPreviews()
            activeLayer = .chinese
            presentationMode = .compact
            engineSnapshot = CompositionSnapshot(
                rawInput: rawInput,
                markedText: rawInput,
                candidates: [],
                selectedIndex: 0,
                pageIndex: 0,
                isComposing: true
            )
            publishSnapshot()
            return
        }

        presentationMode = .compact
        updateEngineSnapshot(engineSession.updateInput(rawInput))
    }

    private func updateEngineSnapshot(_ newSnapshot: CompositionSnapshot) {
        let previousCandidateIDs = visibleCandidateIDs(for: engineSnapshot)
        engineSnapshot = newSnapshot
        if rawInput != engineSnapshot.rawInput {
            rawInput = engineSnapshot.rawInput
        }

        if !engineSnapshot.isComposing {
            activeLayer = .chinese
            presentationMode = .compact
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

    private func moveEngineSelection(to localIndex: Int) {
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

    private func selectCandidate(row: Int, column: Int, clampColumn: Bool) {
        guard row >= 0, column >= 0 else {
            publishSnapshot()
            return
        }

        let count = candidateCount(inRow: row)
        guard count > 0 else {
            publishSnapshot()
            return
        }

        guard clampColumn || column < count else {
            publishSnapshot()
            return
        }

        let targetColumn = clampColumn ? min(column, count - 1) : column
        let targetIndex = row * compactColumnCount + targetColumn
        guard targetIndex < engineSnapshot.candidates.count else {
            publishSnapshot()
            return
        }

        moveEngineSelection(to: targetIndex)
    }

    private func moveToAdjacentPage(
        direction: PageDirection,
        preferredColumn: Int,
        preferredRow: Int?
    ) {
        let previousPageIndex = engineSnapshot.pageIndex
        let newSnapshot = engineSession.turnPage(direction)

        guard newSnapshot.pageIndex != previousPageIndex else {
            publishSnapshot()
            return
        }

        updateEngineSnapshot(newSnapshot)

        let targetRow: Int
        switch direction {
        case .next:
            targetRow = preferredRow ?? 0
        case .previous:
            targetRow = preferredRow ?? max(0, currentRowCount - 1)
        }

        let clampedRow = min(max(0, targetRow), max(0, currentRowCount - 1))
        let clampedColumn = min(preferredColumn, max(0, candidateCount(inRow: clampedRow) - 1))
        selectCandidate(row: clampedRow, column: clampedColumn, clampColumn: true)
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
        guard currentSelectedFlatIndex >= 0, currentSelectedFlatIndex < engineSnapshot.candidates.count else {
            return nil
        }
        return engineSnapshot.candidates[currentSelectedFlatIndex].id
    }

    private func makeSnapshot() -> BilingualCompositionSnapshot {
        guard engineSnapshot.isComposing else {
            return .idle
        }

        guard !engineSnapshot.candidates.isEmpty else {
            return BilingualCompositionSnapshot(
                rawInput: rawInput,
                markedText: rawInput,
                items: [],
                pageIndex: 0,
                activeLayer: .chinese,
                presentationMode: .compact,
                selectedRow: 0,
                selectedColumn: 0,
                compactColumnCount: compactColumnCount,
                expandedRowCount: expandedRowCount,
                isComposing: true
            )
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
            pageIndex: engineSnapshot.pageIndex,
            activeLayer: activeLayer,
            presentationMode: presentationMode,
            selectedRow: currentSelectedRowForSelection,
            selectedColumn: currentSelectedColumn,
            compactColumnCount: compactColumnCount,
            expandedRowCount: expandedRowCount,
            isComposing: engineSnapshot.isComposing
        )
    }

    private func makeMarkedText(items: [BilingualCandidateItem]) -> String {
        guard currentSelectedFlatIndex >= 0, currentSelectedFlatIndex < items.count else {
            return engineSnapshot.markedText
        }

        let selectedItem = items[currentSelectedFlatIndex]
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

    private func rowCount(for candidates: [Candidate]) -> Int {
        guard !candidates.isEmpty else { return 0 }
        return ((candidates.count - 1) / compactColumnCount) + 1
    }

    private func candidateCount(inRow row: Int) -> Int {
        guard row >= 0 else { return 0 }
        let startIndex = row * compactColumnCount
        guard startIndex < engineSnapshot.candidates.count else { return 0 }
        return min(compactColumnCount, engineSnapshot.candidates.count - startIndex)
    }

    private func normalize(_ string: String) -> String {
        string
            .lowercased()
            .filter { $0.isLetter || $0 == "'" }
    }
}
