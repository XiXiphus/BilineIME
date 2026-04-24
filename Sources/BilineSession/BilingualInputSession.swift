import BilineCore
import BilinePreview
import Foundation

public final class BilingualInputSession: @unchecked Sendable {
    public var onSnapshotUpdate: ((BilingualCompositionSnapshot) -> Void)?

    public var snapshot: BilingualCompositionSnapshot {
        withStateLock { currentSnapshot }
    }

    public var canDeleteBackward: Bool { withStateLock { !rawInput.isEmpty } }
    public var hasCandidates: Bool { withStateLock { !currentSnapshot.items.isEmpty } }
    public var punctuationForm: PunctuationForm { settingsStore.punctuationForm }
    public internal(set) var compositionMode: CompositionMode = .candidateCompact
    public internal(set) var hasEverExpandedInCurrentComposition = false
    public internal(set) var hasExplicitCandidateSelection = false

    /// Bundle identifier of the host app that owns the active client. Set
    /// by the controller on client switch; consumed by the post-commit
    /// pipeline so transforms can branch on host when needed.
    public var hostBundleID: String?
    /// Pipeline applied to every committed text just before it leaves the
    /// session. Defaults to empty so behavior is unchanged for callers that
    /// do not opt in.
    public var postCommitPipeline: PostCommitPipeline = .empty

    let stateLock = NSRecursiveLock()
    let settingsStore: any SettingsStore
    let previewCoordinator: PreviewCoordinator
    var engineSession: any CandidateEngineSession

    /// Most recent (text, timestamp) the pipeline saw. Transforms key off
    /// this to detect "did the previous commit just happen and need a
    /// follow-up space?" without reaching back into the session.
    var lastCommitTextForPipeline: String?
    var lastCommitTimestampForPipeline: Date?
    /// Bounded chronological history for multi-step pattern detection. See
    /// `PostCommitContext.commitHistoryLimit`.
    var commitHistoryForPipeline: [String] = []

    var currentSnapshot: BilingualCompositionSnapshot = .idle
    var engineSnapshot: CompositionSnapshot = .idle
    var rawInput = ""
    var rawCursorIndex = 0
    var activeLayer: ActiveLayer = .chinese
    var presentationMode: CandidatePresentationMode = .compact
    var preferredCandidateColumn = 0
    var rawSuffixAfterActiveChunk = ""
    var displaySuffixForWholeCandidate = ""
    var previewStates: [String: BilingualPreviewState] = [:]
    var previewTasks: [String: Task<Void, Never>] = [:]
    let sessionID = UUID()
    let pinyinSegmenter = PinyinInputSegmenter()
    var compositionRevision = 0

    var lockDepth = 0
    var hasPendingNotification = false

    /// When true, snapshot updates produced inside `withStateLock` are
    /// "consumed" without invoking `onSnapshotUpdate`. Sync key-event
    /// handling sets this to render exactly once at the end of
    /// `routeAndApply`, eliminating the redundant render that previously
    /// fired both from the snapshot callback and from the controller's
    /// trailing `render(client:)`. Async preview tasks leave this `false`
    /// so their state changes still notify subscribers.
    public var suppressSnapshotNotification = false

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
        withStateLock {
            clearPreviews()
        }
    }
}
