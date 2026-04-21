import BilineCore

extension BilingualInputSession {
    var compactColumnCount: Int {
        max(1, settingsStore.compactColumnCount)
    }

    var expandedRowCount: Int {
        max(1, settingsStore.expandedRowCount)
    }

    var currentSelectedFlatIndex: Int {
        engineSnapshot.selectedIndex
    }

    var currentSelectedRow: Int {
        currentSelectedFlatIndex / compactColumnCount
    }

    var currentSelectedColumn: Int {
        currentSelectedFlatIndex % compactColumnCount
    }

    var currentSelectedRowForSelection: Int {
        presentationMode == .expanded ? currentSelectedRow : 0
    }

    var currentRowCount: Int {
        rowCount(for: engineSnapshot.candidates)
    }

    var currentItem: BilingualCandidateItem? {
        guard currentSelectedFlatIndex >= 0, currentSelectedFlatIndex < currentSnapshot.items.count
        else {
            return nil
        }
        return currentSnapshot.items[currentSelectedFlatIndex]
    }

    var renderedRawInput: String {
        PunctuationPolicy.renderPreedit(rawInput, form: settingsStore.punctuationForm)
    }

    func makeSnapshot() -> BilingualCompositionSnapshot {
        guard engineSnapshot.isComposing else {
            return .idle
        }

        if engineSnapshot.candidates.isEmpty {
            return BilingualCompositionSnapshot(
                rawInput: rawInput,
                remainingRawInput: rawInput,
                displayRawInput: renderedRawInput,
                markedText: renderedRawInput,
                items: [],
                pageIndex: 0,
                activeLayer: activeLayer,
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

        return BilingualCompositionSnapshot(
            rawInput: engineSnapshot.rawInput,
            remainingRawInput: engineSnapshot.remainingRawInput,
            displayRawInput: renderedRawInput,
            markedText: renderedRawInput,
            items: items,
            pageIndex: engineSnapshot.pageIndex,
            activeLayer: activeLayer,
            presentationMode: presentationMode,
            selectedRow: currentSelectedRowForSelection,
            selectedColumn: currentSelectedColumn,
            compactColumnCount: compactColumnCount,
            expandedRowCount: expandedRowCount,
            isComposing: true
        )
    }

    func publishSnapshot() {
        currentSnapshot = makeSnapshot()
        hasPendingNotification = true
    }

    func rowCount(for candidates: [Candidate]) -> Int {
        guard !candidates.isEmpty else { return 0 }
        return ((candidates.count - 1) / compactColumnCount) + 1
    }

    func candidateCount(inRow row: Int) -> Int {
        guard row >= 0 else { return 0 }
        let startIndex = row * compactColumnCount
        guard startIndex < engineSnapshot.candidates.count else { return 0 }
        return min(compactColumnCount, engineSnapshot.candidates.count - startIndex)
    }
}
