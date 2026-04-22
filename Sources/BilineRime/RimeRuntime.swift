import CBilineRime
import Foundation

final class RimeRuntime: @unchecked Sendable {
    static let shared = RimeRuntime()

    private let stateLock = NSRecursiveLock()
    private var preparedSettings: RimeSettings?
    private var isInitialized = false
    private var paths: RimePaths?
    private var tokenizer: PinyinTokenizer?
    private var lexicon: RimeLexicon?

    func prepare(settings: RimeSettings) throws {
        try withStateLock {
            if isInitialized, preparedSettings == settings {
                return
            }

            let resolvedPaths = try RimePaths.resolve()
            try resolvedPaths.prepareFilesystem(settings: settings)

            if isInitialized {
                BRimeFinalize()
                isInitialized = false
            }

            guard
                BRimeSetup(
                    resolvedPaths.libraryPath.path,
                    resolvedPaths.sharedDataDir.path,
                    resolvedPaths.userDataDir.path,
                    resolvedPaths.logDir.path,
                    "rime.bilineime"
                )
            else {
                throw RimeError.setupFailed(Self.lastError())
            }

            for schemaFileName in ["biline_pinyin_simp.schema.yaml", "biline_pinyin_trad.schema.yaml"] {
                let schemaPath = resolvedPaths.sharedDataDir
                    .appendingPathComponent(schemaFileName)
                    .path
                guard BRimeDeploySchema(schemaPath) else {
                    throw RimeError.deployFailed(Self.lastError())
                }
            }

            tokenizer = PinyinTokenizer(syllables: [])
            lexicon = try RimeLexicon.fromDictionaryFiles(
                at: [
                    resolvedPaths.sharedDataDir.appendingPathComponent("rime_ice.dict.yaml"),
                    resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/8105.dict.yaml"),
                    resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/base.dict.yaml"),
                    resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/ext.dict.yaml"),
                    resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/tencent.dict.yaml"),
                    resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/others.dict.yaml"),
                    resolvedPaths.sharedDataDir.appendingPathComponent("biline_phrases.dict.yaml"),
                    resolvedPaths.sharedDataDir.appendingPathComponent(
                        "biline_modern_phrases.dict.yaml"),
                ]
            )
            preparedSettings = settings
            paths = resolvedPaths
            isInitialized = true
        }
    }

    func makeSession(schemaID: String, settings: RimeSettings) throws -> BRimeSessionId {
        try withStateLock {
            try prepare(settings: settings)

            let sessionID = BRimeCreateSession()
            guard sessionID != 0 else {
                throw RimeError.sessionCreateFailed(Self.lastError())
            }

            guard BRimeSelectSchema(sessionID, schemaID) else {
                BRimeDestroySession(sessionID)
                throw RimeError.setupFailed(Self.lastError())
            }

            try applySessionOptions(sessionID: sessionID, settings: settings)
            return sessionID
        }
    }

    func resetSession(_ sessionID: BRimeSessionId, schemaID: String, settings: RimeSettings) throws
        -> BRimeSessionId
    {
        try withStateLock {
            _ = BRimeDestroySession(sessionID)
            return try makeSession(schemaID: schemaID, settings: settings)
        }
    }

    func applySessionOptions(sessionID: BRimeSessionId, settings: RimeSettings) throws {
        try withStateLock {
            let requiredOptions: [(String, Bool)] = [
                ("ascii_mode", false),
                ("full_shape", false),
                ("ascii_punct", false),
            ]

            for (optionName, enabled) in requiredOptions {
                guard BRimeSetOption(sessionID, optionName, enabled) else {
                    throw RimeError.setupFailed(Self.lastError())
                }
            }
        }
    }

    func makeTokenizer(settings: RimeSettings) throws -> PinyinTokenizer {
        try withStateLock {
            try prepare(settings: settings)
            guard let tokenizer else {
                throw RimeError.missingResource("pinyin.yaml")
            }
            return tokenizer
        }
    }

    func makeLexicon(settings: RimeSettings) throws -> RimeLexicon {
        try withStateLock {
            try prepare(settings: settings)
            guard let lexicon else {
                throw RimeError.missingResource("biline_phrases.dict.yaml")
            }
            return lexicon
        }
    }

    private func withStateLock<T>(_ body: () throws -> T) rethrows -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try body()
    }

    private static func lastError() -> String {
        guard let cString = BRimeCopyLastError() else {
            return "unknown error"
        }
        defer { BRimeFreeCString(cString) }
        return String(cString: cString)
    }
}
