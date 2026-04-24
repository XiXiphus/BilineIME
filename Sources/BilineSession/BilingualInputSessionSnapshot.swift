import BilineCore

extension BilingualInputSession {
    var showsEnglishCandidates: Bool {
        settingsStore.bilingualModeEnabled
    }

    var effectiveActiveLayer: ActiveLayer {
        showsEnglishCandidates ? activeLayer : .chinese
    }

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

    var markedSelectionLocation: Int {
        let cursorIndex = min(max(0, rawCursorIndex), rawInput.count)
        let rawPrefix = String(rawInput.prefix(cursorIndex))
        return PunctuationPolicy.renderPreedit(rawPrefix, form: settingsStore.punctuationForm).count
    }

    struct MarkedPreeditDisplay {
        let text: String
        let selectionLocation: Int
    }

    var rawBufferPreeditDisplay: MarkedPreeditDisplay {
        MarkedPreeditDisplay(
            text: renderedRawInput,
            selectionLocation: markedSelectionLocation
        )
    }

    var candidatePreeditDisplay: MarkedPreeditDisplay {
        guard !rawInput.isEmpty else {
            return MarkedPreeditDisplay(text: "", selectionLocation: 0)
        }

        let selectedConsumedTokenCount = selectedCandidateConsumedTokenCount
        if !rawSuffixAfterActiveChunk.isEmpty,
            rawInput.hasSuffix(rawSuffixAfterActiveChunk)
        {
            let queryInput = String(rawInput.dropLast(rawSuffixAfterActiveChunk.count))
            let remainingInQuery = mixedPrefixRemainingRawInput()
            let tokens = pinyinTokens(
                for: queryInput,
                consumedTokenCount: selectedConsumedTokenCount,
                remainingRawInput: remainingInQuery
            )
            return renderMixedPreeditDisplay(
                queryInput: queryInput,
                queryTokens: tokens,
                rawSuffix: rawSuffixAfterActiveChunk
            )
        }

        let tokens = pinyinTokens(
            for: rawInput,
            consumedTokenCount: selectedConsumedTokenCount,
            remainingRawInput: engineSnapshot.remainingRawInput
        )
        return renderPinyinPreeditDisplay(
            rawText: rawInput,
            rawStartOffset: 0,
            tokens: tokens,
            insertsLeadingSeparator: false
        )
    }

    func makeSnapshot() -> BilingualCompositionSnapshot {
        guard engineSnapshot.isComposing else {
            return .idleSnapshot(revision: compositionRevision)
        }

        if engineSnapshot.candidates.isEmpty {
            let preeditDisplay = rawBufferPreeditDisplay
            return BilingualCompositionSnapshot(
                revision: compositionRevision,
                rawInput: rawInput,
                remainingRawInput: rawInput,
                displayRawInput: preeditDisplay.text,
                markedText: preeditDisplay.text,
                rawCursorIndex: rawCursorIndex,
                markedSelectionLocation: preeditDisplay.selectionLocation,
                items: [],
                showsEnglishCandidates: false,
                pageIndex: 0,
                activeLayer: effectiveActiveLayer,
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
                previewState: showsEnglishCandidates
                    ? (previewStates[candidate.id] ?? fallbackPreviewState())
                    : .unavailable
            )
        }
        let preeditDisplay = candidatePreeditDisplay

        return BilingualCompositionSnapshot(
            revision: compositionRevision,
            rawInput: engineSnapshot.rawInput,
            remainingRawInput: engineSnapshot.remainingRawInput,
            displayRawInput: preeditDisplay.text,
            markedText: preeditDisplay.text,
            rawCursorIndex: rawCursorIndex,
            markedSelectionLocation: preeditDisplay.selectionLocation,
            items: items,
            showsEnglishCandidates: showsEnglishCandidates,
            pageIndex: engineSnapshot.pageIndex,
            activeLayer: effectiveActiveLayer,
            presentationMode: presentationMode,
            selectedRow: currentSelectedRowForSelection,
            selectedColumn: currentSelectedColumn,
            compactColumnCount: compactColumnCount,
            expandedRowCount: expandedRowCount,
            isComposing: true
        )
    }

    func publishSnapshot() {
        prepareSelectedPreview()
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

    private var selectedCandidateConsumedTokenCount: Int {
        let index = engineSnapshot.selectedIndex
        guard index >= 0, index < engineSnapshot.candidates.count else {
            return engineSnapshot.consumedTokenCount
        }
        return engineSnapshot.candidates[index].consumedTokenCount
    }

    private func mixedPrefixRemainingRawInput() -> String {
        var remainingRawInput = engineSnapshot.remainingRawInput
        if !rawSuffixAfterActiveChunk.isEmpty,
            remainingRawInput.hasSuffix(rawSuffixAfterActiveChunk)
        {
            remainingRawInput.removeLast(rawSuffixAfterActiveChunk.count)
        }
        return remainingRawInput
    }

    private func pinyinTokens(
        for input: String,
        consumedTokenCount: Int,
        remainingRawInput: String
    ) -> [String] {
        let tokenizations = pinyinSegmenter.tokenizeAll(input)
        guard !tokenizations.isEmpty else {
            return displayPinyinTokens(for: input)
        }

        if consumedTokenCount > 0 {
            for tokens in tokenizations where tokens.count >= consumedTokenCount {
                let suffix = Array(tokens.dropFirst(consumedTokenCount)).joined()
                if suffix == remainingRawInput {
                    return tokens
                }
            }
        }

        return tokenizations[0]
    }

    private func displayPinyinTokens(for input: String) -> [String] {
        let boundaries = pinyinSegmenter.blockBoundaries(in: input)
        guard boundaries.count > 1 else {
            return input.isEmpty ? [] : [input]
        }

        var tokens: [String] = []
        for index in boundaries.indices.dropLast() {
            let startOffset = boundaries[index]
            let endOffset = boundaries[index + 1]
            guard startOffset < endOffset else { continue }
            let start = input.index(input.startIndex, offsetBy: startOffset)
            let end = input.index(input.startIndex, offsetBy: endOffset)
            let token = input[start..<end].filter { $0 != "'" }
            guard !token.isEmpty else { continue }
            tokens.append(String(token))
        }
        return tokens.isEmpty && !input.isEmpty ? [input] : tokens
    }

    private func renderMixedPreeditDisplay(
        queryInput: String,
        queryTokens: [String],
        rawSuffix: String
    ) -> MarkedPreeditDisplay {
        var display = MarkedPreeditBuilder(rawCursorIndex: rawCursorIndex)
        display.appendPinyin(
            queryInput,
            rawStartOffset: 0,
            tokens: queryTokens,
            insertsLeadingSeparator: false
        )

        var run = ""
        var runKind: MixedPreeditRunKind?
        var runStartOffset = queryInput.count
        var rawOffset = queryInput.count

        func flushRun() {
            guard let runKind, !run.isEmpty else { return }
            switch runKind {
            case .uppercaseLatin:
                display.appendLiteral(run, rawStartOffset: runStartOffset)
            case .pinyin:
                display.appendPinyin(
                    run,
                    rawStartOffset: runStartOffset,
                    tokens: pinyinTokens(for: run, consumedTokenCount: 0, remainingRawInput: ""),
                    insertsLeadingSeparator: true
                )
            case .literal:
                display.appendLiteral(run, rawStartOffset: runStartOffset)
            }
            run.removeAll(keepingCapacity: true)
        }

        for character in rawSuffix {
            let kind = mixedPreeditRunKind(for: character)
            if runKind != kind {
                flushRun()
                runKind = kind
                runStartOffset = rawOffset
            }
            run.append(character)
            rawOffset += 1
        }
        flushRun()

        return display.makeDisplay()
    }

    private func renderPinyinPreeditDisplay(
        rawText: String,
        rawStartOffset: Int,
        tokens: [String],
        insertsLeadingSeparator: Bool
    ) -> MarkedPreeditDisplay {
        var display = MarkedPreeditBuilder(rawCursorIndex: rawCursorIndex)
        display.appendPinyin(
            rawText,
            rawStartOffset: rawStartOffset,
            tokens: tokens,
            insertsLeadingSeparator: insertsLeadingSeparator
        )
        return display.makeDisplay()
    }

    private func mixedPreeditRunKind(for character: Character) -> MixedPreeditRunKind {
        guard character.unicodeScalars.count == 1,
            let scalar = character.unicodeScalars.first,
            scalar.isASCII
        else {
            return .literal
        }

        switch scalar.value {
        case 65...90:
            return .uppercaseLatin
        case 97...122, 39:
            return .pinyin
        default:
            return .literal
        }
    }

}

private enum MixedPreeditRunKind: Equatable {
    case uppercaseLatin
    case pinyin
    case literal
}

private struct MarkedPreeditBuilder {
    private let rawCursorIndex: Int
    private var text = ""
    private var selectionLocation: Int?

    init(rawCursorIndex: Int) {
        self.rawCursorIndex = max(0, rawCursorIndex)
    }

    mutating func appendPinyin(
        _ rawText: String,
        rawStartOffset: Int,
        tokens: [String],
        insertsLeadingSeparator: Bool
    ) {
        guard !rawText.isEmpty else { return }
        appendSeparatorIfNeeded(
            rawStartOffset: rawStartOffset,
            insertsLeadingSeparator: insertsLeadingSeparator
        )

        let normalizedCursorOffset = normalizedPinyinCursorOffset(
            in: rawText,
            rawStartOffset: rawStartOffset
        )
        var normalizedOffset = 0
        let tokens = tokens.isEmpty ? [rawText] : tokens

        for (index, token) in tokens.enumerated() {
            if index > 0 {
                markSelectionIfNeeded(
                    rawStartOffset: rawStartOffset,
                    rawEndOffset: rawStartOffset + rawText.count,
                    normalizedOffset: normalizedOffset,
                    normalizedCursorOffset: normalizedCursorOffset
                )
                text.append(" ")
            }

            for character in token {
                markSelectionIfNeeded(
                    rawStartOffset: rawStartOffset,
                    rawEndOffset: rawStartOffset + rawText.count,
                    normalizedOffset: normalizedOffset,
                    normalizedCursorOffset: normalizedCursorOffset
                )
                text.append(character)
                normalizedOffset += 1
            }
        }

        markSelectionIfNeeded(
            rawStartOffset: rawStartOffset,
            rawEndOffset: rawStartOffset + rawText.count,
            normalizedOffset: normalizedOffset,
            normalizedCursorOffset: normalizedCursorOffset
        )
    }

    mutating func appendLiteral(_ rawText: String, rawStartOffset: Int) {
        guard !rawText.isEmpty else { return }
        appendSeparatorIfNeeded(rawStartOffset: rawStartOffset, insertsLeadingSeparator: true)

        for offset in 0..<rawText.count {
            if rawCursorIndex == rawStartOffset + offset {
                selectionLocation = selectionLocation ?? text.count
            }
            let index = rawText.index(rawText.startIndex, offsetBy: offset)
            text.append(rawText[index])
        }

        if rawCursorIndex == rawStartOffset + rawText.count {
            selectionLocation = selectionLocation ?? text.count
        }
    }

    func makeDisplay() -> BilingualInputSession.MarkedPreeditDisplay {
        BilingualInputSession.MarkedPreeditDisplay(
            text: text,
            selectionLocation: selectionLocation ?? text.count
        )
    }

    private mutating func appendSeparatorIfNeeded(
        rawStartOffset: Int,
        insertsLeadingSeparator: Bool
    ) {
        guard insertsLeadingSeparator, !text.isEmpty else { return }
        if rawCursorIndex == rawStartOffset {
            selectionLocation = selectionLocation ?? text.count
        }
        text.append(" ")
    }

    private mutating func markSelectionIfNeeded(
        rawStartOffset: Int,
        rawEndOffset: Int,
        normalizedOffset: Int,
        normalizedCursorOffset: Int?
    ) {
        guard rawCursorIndex >= rawStartOffset, rawCursorIndex <= rawEndOffset else { return }
        guard normalizedCursorOffset == normalizedOffset else { return }
        selectionLocation = selectionLocation ?? text.count
    }

    private func normalizedPinyinCursorOffset(
        in rawText: String,
        rawStartOffset: Int
    ) -> Int? {
        let rawEndOffset = rawStartOffset + rawText.count
        guard rawCursorIndex >= rawStartOffset, rawCursorIndex <= rawEndOffset else {
            return nil
        }

        let cursorOffset = rawCursorIndex - rawStartOffset
        var normalizedOffset = 0
        for (offset, character) in rawText.enumerated() {
            if offset >= cursorOffset { break }
            if character != "'" {
                normalizedOffset += 1
            }
        }
        return normalizedOffset
    }
}
