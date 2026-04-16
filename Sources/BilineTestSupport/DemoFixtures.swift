import BilineCore
import BilineMocks
import BilinePreview
import Foundation

public enum DemoFixtures {
    public static func makeEngineFactory() -> FixtureCandidateEngineFactory {
        .demo()
    }

    public static func makeSession(pageSize: Int = 9) -> any CandidateEngineSession {
        makeEngineFactory().makeSession(config: EngineConfig(pageSize: pageSize))
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
