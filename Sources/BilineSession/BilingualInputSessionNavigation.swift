import BilineCore
import Foundation

extension BilingualInputSession {
    public func moveSelection(_ direction: SelectionDirection) {
        moveColumn(direction)
    }

    public func moveColumn(_ direction: SelectionDirection) {
        withStateLock {
            guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else { return }

            let delta = direction == .next ? 1 : -1
            let targetColumn = currentSelectedColumn + delta
            selectCandidate(
                row: currentSelectedRowForSelection,
                column: targetColumn,
                clampColumn: false,
                updatesPreferredColumn: true
            )
        }
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
        withStateLock {
            guard engineSnapshot.isComposing else { return }
            guard !engineSnapshot.candidates.isEmpty else {
                publishSnapshot()
                return
            }

            moveToAdjacentPage(
                direction: direction,
                preferredColumn: preferredCandidateColumn,
                preferredRow: currentSelectedRow
            )
        }
    }

    public func selectCandidate(at localIndex: Int) {
        withStateLock {
            guard localIndex >= 0, localIndex < engineSnapshot.candidates.count else { return }
            if moveEngineSelection(to: localIndex) {
                preferredCandidateColumn = localIndex % compactColumnCount
            }
        }
    }

    public func selectColumn(at columnIndex: Int) {
        withStateLock {
            guard engineSnapshot.isComposing else { return }
            selectCandidate(
                row: currentSelectedRowForSelection,
                column: columnIndex,
                clampColumn: false,
                updatesPreferredColumn: true
            )
        }
    }

    public func expandAndAdvanceRow() {
        withStateLock {
            guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else { return }

            let currentColumn = currentSelectedColumn
            preferredCandidateColumn = currentColumn
            hasEverExpandedInCurrentComposition = true
            compositionMode = .candidateExpanded
            presentationMode = .expanded

            let nextRow = 1
            if nextRow < currentRowCount {
                let targetColumn = min(currentColumn, max(0, candidateCount(inRow: nextRow) - 1))
                selectCandidate(
                    row: nextRow,
                    column: targetColumn,
                    clampColumn: true,
                    updatesPreferredColumn: false
                )
                return
            }

            moveToAdjacentPage(
                direction: .next,
                preferredColumn: currentColumn,
                preferredRow: 0
            )
        }
    }

    public func browseNextRow() {
        withStateLock {
            guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else {
                publishSnapshot()
                return
            }

            compositionMode = .candidateExpanded
            presentationMode = .expanded
            let targetRow = currentSelectedRow + 1
            if targetRow < currentRowCount {
                let targetColumn = min(
                    preferredCandidateColumn, max(0, candidateCount(inRow: targetRow) - 1))
                selectCandidate(
                    row: targetRow,
                    column: targetColumn,
                    clampColumn: true,
                    updatesPreferredColumn: false
                )
                return
            }

            moveToAdjacentPage(
                direction: .next, preferredColumn: preferredCandidateColumn, preferredRow: 0)
        }
    }

    public func browsePreviousRow() {
        withStateLock {
            guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else {
                publishSnapshot()
                return
            }

            guard presentationMode == .expanded else {
                publishSnapshot()
                return
            }

            if currentSelectedRow == 0 {
                if engineSnapshot.pageIndex > 0 {
                    moveToAdjacentPage(
                        direction: .previous,
                        preferredColumn: preferredCandidateColumn,
                        preferredRow: nil
                    )
                } else {
                    collapseToCompactAndSelectFirst()
                }
                return
            }

            let targetRow = currentSelectedRow - 1
            let targetColumn = min(
                preferredCandidateColumn, max(0, candidateCount(inRow: targetRow) - 1))
            selectCandidate(
                row: targetRow,
                column: targetColumn,
                clampColumn: true,
                updatesPreferredColumn: false
            )
        }
    }

    public func collapseToCompactAndSelectFirst() {
        withStateLock {
            guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else {
                publishSnapshot()
                return
            }

            compositionMode = .candidateCompact
            presentationMode = .compact
            preferredCandidateColumn = 0
            selectCandidate(row: 0, column: 0, clampColumn: true, updatesPreferredColumn: false)
        }
    }

    public func setActiveLayer(_ layer: ActiveLayer) {
        if Thread.isMainThread {
            setActiveLayerOnCurrentThread(layer)
            return
        }

        DispatchQueue.main.sync {
            self.setActiveLayerOnCurrentThread(layer)
        }
    }

    public func toggleActiveLayer() {
        if Thread.isMainThread {
            toggleActiveLayerOnCurrentThread()
            return
        }

        DispatchQueue.main.sync {
            self.toggleActiveLayerOnCurrentThread()
        }
    }

    func setActiveLayerOnCurrentThread(_ layer: ActiveLayer) {
        withStateLock {
            guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else { return }
            guard showsEnglishCandidates else {
                if activeLayer != .chinese {
                    activeLayer = .chinese
                    publishSnapshot()
                }
                return
            }
            guard activeLayer != layer else { return }
            activeLayer = layer
            publishSnapshot()
        }
    }

    func toggleActiveLayerOnCurrentThread() {
        withStateLock {
            guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else { return }
            guard showsEnglishCandidates else {
                if activeLayer != .chinese {
                    activeLayer = .chinese
                    publishSnapshot()
                }
                return
            }
            activeLayer = activeLayer == .chinese ? .english : .chinese
            publishSnapshot()
        }
    }

    @discardableResult
    func moveEngineSelection(to localIndex: Int) -> Bool {
        let delta = localIndex - engineSnapshot.selectedIndex
        guard delta != 0 else {
            publishSnapshot()
            return true
        }

        hasExplicitCandidateSelection = true
        let direction: SelectionDirection = delta > 0 ? .next : .previous
        for _ in 0..<abs(delta) {
            engineSnapshot = engineSession.moveSelection(direction)
        }
        updateEngineSnapshot(engineSnapshot)
        return true
    }

    @discardableResult
    func selectCandidate(
        row: Int,
        column: Int,
        clampColumn: Bool,
        updatesPreferredColumn: Bool
    ) -> Bool {
        guard row >= 0, column >= 0 else {
            publishSnapshot()
            return false
        }

        let count = candidateCount(inRow: row)
        guard count > 0 else {
            publishSnapshot()
            return false
        }

        guard clampColumn || column < count else {
            publishSnapshot()
            return false
        }

        let targetColumn = clampColumn ? min(column, count - 1) : column
        let targetIndex = row * compactColumnCount + targetColumn
        guard targetIndex < engineSnapshot.candidates.count else {
            publishSnapshot()
            return false
        }

        if moveEngineSelection(to: targetIndex), updatesPreferredColumn {
            preferredCandidateColumn = targetColumn
        }
        return true
    }

    func moveToAdjacentPage(
        direction: PageDirection,
        preferredColumn: Int,
        preferredRow: Int?
    ) {
        let previousPageIndex = engineSnapshot.pageIndex
        let previousSelectedIndex = engineSnapshot.selectedIndex
        let newSnapshot = engineSession.turnPage(direction)

        guard newSnapshot.pageIndex != previousPageIndex else {
            restoreEngineSelectionIfNeeded(
                from: newSnapshot,
                targetSelectedIndex: previousSelectedIndex
            )
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
        selectCandidate(
            row: clampedRow,
            column: clampedColumn,
            clampColumn: true,
            updatesPreferredColumn: false
        )
    }

    private func restoreEngineSelectionIfNeeded(
        from snapshot: CompositionSnapshot,
        targetSelectedIndex: Int
    ) {
        guard snapshot.selectedIndex != targetSelectedIndex else {
            publishSnapshot()
            return
        }

        let direction: SelectionDirection =
            targetSelectedIndex > snapshot.selectedIndex ? .next : .previous
        var restoredSnapshot = snapshot
        for _ in 0..<abs(targetSelectedIndex - snapshot.selectedIndex) {
            restoredSnapshot = engineSession.moveSelection(direction)
        }
        updateEngineSnapshot(restoredSnapshot)
    }
}
