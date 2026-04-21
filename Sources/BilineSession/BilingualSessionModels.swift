import BilineCore
import Foundation

public enum ActiveLayer: String, Sendable, Equatable, Codable {
    case chinese
    case english
}

public enum CandidatePresentationMode: String, Sendable, Equatable, Codable {
    case compact
    case expanded
}

public enum CompositionMode: String, Sendable, Equatable, Codable {
    case candidateCompact
    case candidateExpanded
    case rawBufferOnly
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
        guard case .ready(let text) = previewState else {
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
    public let remainingRawInput: String
    public let displayRawInput: String
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
        remainingRawInput: String,
        displayRawInput: String,
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
        self.remainingRawInput = remainingRawInput
        self.displayRawInput = displayRawInput
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
        remainingRawInput: "",
        displayRawInput: "",
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

    public var markedSelectionRange: NSRange {
        NSRange(location: markedText.count, length: 0)
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
