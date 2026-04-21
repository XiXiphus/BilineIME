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
        hasEverExpandedInCurrentComposition: Bool = false
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
    }
}
