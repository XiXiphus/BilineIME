import BilineCore

public struct RimeCandidateEngineFactory: CandidateEngineFactory, Sendable {
    private let settings: RimeSettings
    private let tokenizer: PinyinTokenizer
    private let lexicon: RimeLexicon

    public init(
        fuzzyPinyinEnabled: Bool,
        characterForm: CharacterForm
    ) throws {
        let settings = RimeSettings(
            pageSize: 25,
            fuzzyPinyinEnabled: fuzzyPinyinEnabled,
            characterForm: characterForm
        )
        self.settings = settings
        let runtime = RimeRuntime.shared
        self.tokenizer = try runtime.makeTokenizer(settings: settings)
        self.lexicon = try runtime.makeLexicon(settings: settings)
    }

    public func makeSession(config: EngineConfig) -> any CandidateEngineSession {
        do {
            return try RimeCandidateEngineSession(
                schemaID: settings.schemaID,
                settings: RimeSettings(
                    pageSize: config.pageSize,
                    fuzzyPinyinEnabled: settings.fuzzyPinyinEnabled,
                    characterForm: settings.characterForm
                ),
                tokenizer: tokenizer,
                lexicon: lexicon
            )
        } catch {
            fatalError("Unable to create Rime engine session: \(error)")
        }
    }
}
