import BilineCore
import BilinePreview
import BilineSession
import BilineTestSupport

func makeSessionWithEngine(
    snapshotsByInput: [String: CompositionSnapshot],
    commitResult: CommitResult
) -> BilingualInputSession {
    BilingualInputSession(
        settingsStore: StubSettingsStore(),
        engineFactory: StubEngineFactory(
            session: StubCandidateEngineSession(
                snapshotsByInput: snapshotsByInput,
                commitResult: commitResult
            )
        ),
        previewCoordinator: DemoFixtures.makeCoordinator()
    )
}

private struct StubSettingsStore: SettingsStore {
    let targetLanguage: TargetLanguage = .english
    let previewEnabled: Bool = true
    let compactColumnCount: Int = 5
    let expandedRowCount: Int = 5
    let fuzzyPinyinEnabled: Bool = false
    let characterForm: CharacterForm = .simplified
    let punctuationForm: PunctuationForm = .fullwidth

    var pageSize: Int { compactColumnCount * expandedRowCount }
}

private struct StubEngineFactory: CandidateEngineFactory {
    let session: StubCandidateEngineSession

    func makeSession(config: EngineConfig) -> any CandidateEngineSession {
        session
    }
}

private final class StubCandidateEngineSession: CandidateEngineSession, @unchecked Sendable {
    private let snapshotsByInput: [String: CompositionSnapshot]
    private let commitResultValue: CommitResult

    init(snapshotsByInput: [String: CompositionSnapshot], commitResult: CommitResult) {
        self.snapshotsByInput = snapshotsByInput
        self.commitResultValue = commitResult
    }

    func updateInput(_ rawInput: String) -> CompositionSnapshot {
        snapshotsByInput[rawInput] ?? .idle
    }

    func moveSelection(_ direction: SelectionDirection) -> CompositionSnapshot {
        snapshotsByInput.values.first ?? .idle
    }

    func turnPage(_ direction: PageDirection) -> CompositionSnapshot {
        snapshotsByInput.values.first ?? .idle
    }

    func commitSelected() -> CommitResult {
        commitResultValue
    }

    func reset() -> CompositionSnapshot {
        .idle
    }
}
