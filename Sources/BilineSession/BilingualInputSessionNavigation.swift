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
                clampColumn: false
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
                preferredColumn: currentSelectedColumn,
                preferredRow: currentSelectedRow
            )
        }
    }

    public func selectCandidate(at localIndex: Int) {
        withStateLock {
            guard localIndex >= 0, localIndex < engineSnapshot.candidates.count else { return }
            moveEngineSelection(to: localIndex)
        }
    }

    public func selectColumn(at columnIndex: Int) {
        withStateLock {
            guard engineSnapshot.isComposing else { return }
            selectCandidate(
                row: currentSelectedRowForSelection,
                column: columnIndex,
                clampColumn: false
            )
        }
    }

    public func expandAndAdvanceRow() {
        withStateLock {
            guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else { return }

            let currentColumn = currentSelectedColumn
            hasEverExpandedInCurrentComposition = true
            compositionMode = .candidateExpanded
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
                    currentSelectedColumn, max(0, candidateCount(inRow: targetRow) - 1))
                selectCandidate(row: targetRow, column: targetColumn, clampColumn: true)
                return
            }

            moveToAdjacentPage(
                direction: .next, preferredColumn: currentSelectedColumn, preferredRow: 0)
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
                        preferredColumn: currentSelectedColumn,
                        preferredRow: nil
                    )
                } else {
                    collapseToCompactAndSelectFirst()
                }
                return
            }

            let targetRow = currentSelectedRow - 1
            let targetColumn = min(
                currentSelectedColumn, max(0, candidateCount(inRow: targetRow) - 1))
            selectCandidate(row: targetRow, column: targetColumn, clampColumn: true)
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
            selectCandidate(row: 0, column: 0, clampColumn: true)
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
            guard activeLayer != layer else { return }
            activeLayer = layer
            publishSnapshot()
        }
    }

    func toggleActiveLayerOnCurrentThread() {
        withStateLock {
            guard engineSnapshot.isComposing, !engineSnapshot.candidates.isEmpty else { return }
            activeLayer = activeLayer == .chinese ? .english : .chinese
            publishSnapshot()
        }
    }

    func moveEngineSelection(to localIndex: Int) {
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

    func selectCandidate(row: Int, column: Int, clampColumn: Bool) {
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

    func moveToAdjacentPage(
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
}
