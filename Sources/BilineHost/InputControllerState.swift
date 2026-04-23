import BilineCore
import Foundation

public enum InputCompositionMode: Sendable, Equatable {
    case candidateCompact
    case candidateExpanded
    case rawBufferOnly
}

public struct InputControllerState: Sendable, Equatable {
    public let compositionMode: InputCompositionMode
    public let isComposing: Bool
    public let canDeleteBackward: Bool
    public let hasCandidates: Bool
    public let compactColumnCount: Int
    public let punctuationForm: PunctuationForm
    public let pageIndex: Int
    public let selectedRow: Int
    public let isExpandedPresentation: Bool
    public let hasEverExpandedInCurrentComposition: Bool
    public let hasExplicitCandidateSelection: Bool
    public let rawCursorIndex: Int
    public let rawInputLength: Int

    public var isRawCursorAtEnd: Bool {
        rawCursorIndex >= rawInputLength
    }

    public init(
        compositionMode: InputCompositionMode = .candidateCompact,
        isComposing: Bool,
        canDeleteBackward: Bool,
        hasCandidates: Bool,
        compactColumnCount: Int,
        punctuationForm: PunctuationForm = .fullwidth,
        pageIndex: Int = 0,
        selectedRow: Int = 0,
        isExpandedPresentation: Bool = false,
        hasEverExpandedInCurrentComposition: Bool = false,
        hasExplicitCandidateSelection: Bool = false,
        rawCursorIndex: Int = 0,
        rawInputLength: Int = 0
    ) {
        self.compositionMode = compositionMode
        self.isComposing = isComposing
        self.canDeleteBackward = canDeleteBackward
        self.hasCandidates = hasCandidates
        self.compactColumnCount = max(1, compactColumnCount)
        self.punctuationForm = punctuationForm
        self.pageIndex = max(0, pageIndex)
        self.selectedRow = max(0, selectedRow)
        self.isExpandedPresentation = isExpandedPresentation
        self.hasEverExpandedInCurrentComposition = hasEverExpandedInCurrentComposition
        self.hasExplicitCandidateSelection = hasExplicitCandidateSelection
        self.rawInputLength = max(0, rawInputLength)
        self.rawCursorIndex = min(max(0, rawCursorIndex), self.rawInputLength)
    }
}
