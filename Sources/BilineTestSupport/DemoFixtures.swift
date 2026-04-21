import BilineCore
import BilineMocks
import BilinePreview
import BilineSession
import Foundation

public enum DemoFixtures {
    public static func makeEngineFactory() -> FixtureCandidateEngineFactory {
        .demo()
    }

    public static func makeSession(pageSize: Int = 9) -> any CandidateEngineSession {
        makeEngineFactory().makeSession(config: EngineConfig(pageSize: pageSize))
    }

    public static func makeBilingualSession(
        compactColumnCount: Int = 5,
        expandedRowCount: Int = 5,
        delay: Duration = .zero,
        failures: Set<String> = [],
        previewEnabled: Bool = true,
        punctuationForm: PunctuationForm = .fullwidth
    ) -> BilingualInputSession {
        BilingualInputSession(
            settingsStore: DemoSettingsStore(
                previewEnabled: previewEnabled,
                compactColumnCount: compactColumnCount,
                expandedRowCount: expandedRowCount,
                punctuationForm: punctuationForm
            ),
            engineFactory: makeEngineFactory(),
            previewCoordinator: makeCoordinator(delay: delay, failures: failures)
        )
    }

    public static func makeProvider(
        delay: Duration = .zero,
        failures: Set<String> = []
    ) -> MockTranslationProvider {
        MockTranslationProvider(delay: delay, failures: failures)
    }

    public static func makeCoordinator(
        delay: Duration = .zero,
        failures: Set<String> = [],
        debounce: Duration = .zero
    ) -> PreviewCoordinator {
        PreviewCoordinator(
            provider: makeProvider(delay: delay, failures: failures),
            debounce: debounce
        )
    }
}

private struct DemoSettingsStore: SettingsStore {
    let targetLanguage: TargetLanguage = .english
    let previewEnabled: Bool
    let compactColumnCount: Int
    let expandedRowCount: Int
    let fuzzyPinyinEnabled: Bool = false
    let characterForm: CharacterForm = .simplified
    let punctuationForm: PunctuationForm

    var pageSize: Int {
        compactColumnCount * expandedRowCount
    }
}
