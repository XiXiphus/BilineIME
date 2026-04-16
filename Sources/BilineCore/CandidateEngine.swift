import Foundation

public struct EngineConfig: Sendable, Equatable {
    public let pageSize: Int

    public init(pageSize: Int = 9) {
        self.pageSize = max(1, pageSize)
    }
}

public enum SelectionDirection: Sendable, Equatable {
    case next
    case previous
}

public enum PageDirection: Sendable, Equatable {
    case next
    case previous
}

public struct Candidate: Sendable, Equatable, Hashable, Codable, Identifiable {
    public let id: String
    public let surface: String
    public let reading: String
    public let score: Int

    public init(id: String, surface: String, reading: String, score: Int) {
        self.id = id
        self.surface = surface
        self.reading = reading
        self.score = score
    }
}

public struct CompositionSnapshot: Sendable, Equatable {
    public let rawInput: String
    public let markedText: String
    public let candidates: [Candidate]
    public let selectedIndex: Int
    public let pageIndex: Int
    public let isComposing: Bool

    public init(
        rawInput: String,
        markedText: String,
        candidates: [Candidate],
        selectedIndex: Int,
        pageIndex: Int,
        isComposing: Bool
    ) {
        self.rawInput = rawInput
        self.markedText = markedText
        self.candidates = candidates
        self.selectedIndex = selectedIndex
        self.pageIndex = pageIndex
        self.isComposing = isComposing
    }

    public static let idle = CompositionSnapshot(
        rawInput: "",
        markedText: "",
        candidates: [],
        selectedIndex: 0,
        pageIndex: 0,
        isComposing: false
    )
}

public struct CommitResult: Sendable, Equatable {
    public let committedText: String
    public let snapshot: CompositionSnapshot

    public init(committedText: String, snapshot: CompositionSnapshot) {
        self.committedText = committedText
        self.snapshot = snapshot
    }
}

public protocol CandidateEngineSession: Sendable {
    func updateInput(_ rawInput: String) -> CompositionSnapshot
    func moveSelection(_ direction: SelectionDirection) -> CompositionSnapshot
    func turnPage(_ direction: PageDirection) -> CompositionSnapshot
    func commitSelected() -> CommitResult
    func reset() -> CompositionSnapshot
}

public protocol CandidateEngineFactory: Sendable {
    func makeSession(config: EngineConfig) -> any CandidateEngineSession
}
